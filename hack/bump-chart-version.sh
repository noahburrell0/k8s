#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default mode
DRY_RUN=false
TARGET_VERSION=""
INCLUDE_PRERELEASE=false
AUTO_DOWNLOAD=false

# Function to print usage
usage() {
    echo "Usage: $0 <path-to-config-file> [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  path-to-config-file    Path to .conf file containing chart definitions"
    echo ""
    echo "Options:"
    echo "  --dry-run              Show proposed changes without applying them"
    echo "  --version VERSION      Update to specific version (default: latest stable)"
    echo "  --include-prerelease   Include alpha/beta/rc versions (default: stable only)"
    echo "  --download             Automatically download charts after version update"
    echo ""
    echo "Dependencies (required):"
    echo "  - helm (https://helm.sh/docs/intro/install/)"
    echo "  - jq (https://jqlang.github.io/jq/download/)"
    echo "  - crane (https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md)"
    echo ""
    echo "Behavior:"
    echo "  - Checks for newer versions of Helm charts"
    echo "  - Updates VERS values in the config file"
    echo "  - Defaults to latest stable version (excludes alpha/beta/rc)"
    echo "  - Supports both OCI and traditional Helm repositories"
    echo "  - Processes multiple charts in a single config file"
    echo ""
    echo "Configuration file format:"
    echo ""
    echo "  Single chart (Helm):"
    echo "    REPO=https://charts.example.com"
    echo "    CHART=my-chart"
    echo "    VERS=2.0.0"
    echo ""
    echo "  Single chart (OCI):"
    echo "    REPO=oci://charts.example.com/my-chart"
    echo "    VERS=1.0.0"
    echo ""
    echo "  Multiple charts (separated by lines starting with ###):"
    echo "    ### Chart 1"
    echo "    REPO=oci://charts.example.com/my-first-chart"
    echo "    VERS=1.0.0"
    echo ""
    echo "    ### Chart 2"
    echo "    REPO=https://charts.example.com"
    echo "    CHART=my-second-chart"
    echo "    VERS=2.0.0"
    echo ""
    echo "Examples:"
    echo "  # Check and update to latest stable version"
    echo "  $0 path/to/repo.conf"
    echo ""
    echo "  # Dry run to preview changes"
    echo "  $0 path/to/repo.conf --dry-run"
    echo ""
    echo "  # Update to specific version"
    echo "  $0 path/to/repo.conf --version 1.19.0"
    echo ""
    echo "  # Include pre-release versions"
    echo "  $0 path/to/repo.conf --include-prerelease"
    echo ""
    echo "  # Update and download charts automatically"
    echo "  $0 path/to/repo.conf --download"
    exit 1
}

# Function to print error and exit
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to print info
info() {
    echo -e "${GREEN}$1${NC}"
}

# Function to print warning
warn() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to print section header
section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to print dry-run info
dry_run_info() {
    echo -e "${CYAN}[DRY RUN] $1${NC}"
}

# Function to get latest version for OCI chart
get_latest_oci_version() {
    local repo="$1"
    local current_version="$2"

    # Remove oci:// prefix for crane
    local repo_without_oci="${repo#oci://}"

    # Use crane to list all tags
    local all_versions=$(crane ls "$repo_without_oci" 2>/dev/null | \
        grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | \
        sed 's/^v//')

    if [ -z "$all_versions" ]; then
        warn "Could not determine latest version from OCI registry" >&2
        echo "$current_version"
        return
    fi

    # Filter versions based on prerelease flag
    local filtered_versions
    if [ "$INCLUDE_PRERELEASE" = false ]; then
        # Exclude versions with alpha, beta, rc, etc.
        filtered_versions=$(echo "$all_versions" | grep -vE -- '-(alpha|beta|rc|pre|dev|test|snapshot)' || echo "")
    else
        filtered_versions="$all_versions"
    fi

    if [ -z "$filtered_versions" ]; then
        warn "No stable versions found, falling back to current version" >&2
        echo "$current_version"
        return
    fi

    # Get the latest version
    local latest_version=$(echo "$filtered_versions" | sort -V | tail -1)

    if [ -n "$latest_version" ]; then
        echo "$latest_version"
    else
        warn "Could not determine latest version from OCI registry" >&2
        echo "$current_version"
    fi
}

# Function to get latest version for traditional Helm chart
get_latest_helm_version() {
    local repo="$1"
    local chart="$2"
    local current_version="$3"

    local repo_name="bump-temp-repo-$$-$(date +%s)"

    # Add repository
    if ! helm repo add "$repo_name" "$repo" &>/dev/null; then
        warn "Failed to add repository, returning current version" >&2
        echo "$current_version"
        return
    fi

    # Update repository
    helm repo update "$repo_name" &>/dev/null || true

    # Search for all versions of the chart
    local all_versions=$(helm search repo "$repo_name/$chart" --versions --output json 2>/dev/null | \
        jq -r '.[].version' 2>/dev/null || echo "")

    # Clean up
    helm repo remove "$repo_name" &>/dev/null || true

    if [ -z "$all_versions" ]; then
        warn "Could not determine latest version, returning current version" >&2
        echo "$current_version"
        return
    fi

    # Filter versions based on prerelease flag
    local filtered_versions
    if [ "$INCLUDE_PRERELEASE" = false ]; then
        # Exclude versions with alpha, beta, rc, etc.
        filtered_versions=$(echo "$all_versions" | grep -vE -- '-(alpha|beta|rc|pre|dev|test|snapshot)' || echo "")
    else
        filtered_versions="$all_versions"
    fi

    if [ -z "$filtered_versions" ]; then
        warn "No stable versions found, falling back to current version" >&2
        echo "$current_version"
        return
    fi

    # Get the latest version
    local latest_version=$(echo "$filtered_versions" | sort -V | tail -1)

    if [ -n "$latest_version" ]; then
        echo "$latest_version"
    else
        warn "Could not determine latest version, returning current version" >&2
        echo "$current_version"
    fi
}

# Function to compare versions (returns 0 if v1 < v2, 1 if v1 >= v2)
version_less_than() {
    local v1="$1"
    local v2="$2"

    # Use sort -V to compare versions
    if [ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" = "$v1" ] && [ "$v1" != "$v2" ]; then
        return 0
    else
        return 1
    fi
}

# Check required dependencies
MISSING_DEPS=()

if ! command -v helm &> /dev/null; then
    MISSING_DEPS+=("helm")
fi

if ! command -v jq &> /dev/null; then
    MISSING_DEPS+=("jq")
fi

if ! command -v crane &> /dev/null; then
    MISSING_DEPS+=("crane")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    error_exit "Missing required dependencies: ${MISSING_DEPS[*]}\n\nPlease install:\n  - helm: https://helm.sh/docs/intro/install/\n  - jq: https://jqlang.github.io/jq/download/\n  - crane: https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md"
fi

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

CONFIG_FILE=""
NEXT_IS_VERSION=false

for arg in "$@"; do
    if [ "$NEXT_IS_VERSION" = true ]; then
        TARGET_VERSION="$arg"
        NEXT_IS_VERSION=false
        continue
    fi

    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --include-prerelease)
            INCLUDE_PRERELEASE=true
            ;;
        --download)
            AUTO_DOWNLOAD=true
            ;;
        --version)
            NEXT_IS_VERSION=true
            ;;
        -*)
            error_exit "Unknown option: $arg"
            ;;
        *)
            if [ -z "$CONFIG_FILE" ]; then
                CONFIG_FILE="$arg"
            else
                error_exit "Multiple config files specified"
            fi
            ;;
    esac
done

if [ "$NEXT_IS_VERSION" = true ]; then
    error_exit "--version requires a version argument"
fi

if [ -z "$CONFIG_FILE" ]; then
    usage
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Config file not found: $CONFIG_FILE"
fi

# Get absolute path of config file
CONFIG_FILE_ABS="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"

echo ""
if [ "$DRY_RUN" = true ]; then
    dry_run_info "Running in DRY RUN mode - no changes will be made"
    echo ""
fi

if [ -n "$TARGET_VERSION" ]; then
    info "Target version: $TARGET_VERSION"
else
    info "Mode: Latest stable version"
    if [ "$INCLUDE_PRERELEASE" = true ]; then
        info "Including pre-release versions"
    fi
fi

info "Reading configuration from: $CONFIG_FILE_ABS"
echo ""

# Read the entire file content
FILE_CONTENT=$(cat "$CONFIG_FILE_ABS")

# Parse the config file and split into sections with line numbers
declare -a chart_sections=()
declare -a section_start_lines=()
current_section=""
current_start_line=1
line_num=0

while IFS= read -r line || [ -n "$line" ]; do
    ((line_num++)) || true

    # Check if line starts with ###
    if [[ "$line" =~ ^###[[:space:]]*.* ]]; then
        # Save previous section if it exists
        if [ -n "$current_section" ]; then
            chart_sections+=("$current_section")
            section_start_lines+=("$current_start_line")
        fi
        # Start new section
        current_section=""
        current_start_line=$((line_num + 1))
    else
        # Append to current section
        if [ -n "$current_section" ]; then
            current_section+=$'\n'
        fi
        current_section+="$line"
    fi
done <<< "$FILE_CONTENT"

# Add the last section
if [ -n "$current_section" ]; then
    chart_sections+=("$current_section")
    section_start_lines+=("$current_start_line")
fi

# If no sections found (no ### separators), treat entire file as single chart
if [ ${#chart_sections[@]} -eq 0 ]; then
    chart_sections+=("$(cat "$CONFIG_FILE_ABS")")
    section_start_lines+=(1)
fi

total_charts=${#chart_sections[@]}
info "Found $total_charts chart(s) to check"
echo ""

# Track updates
declare -a updates=()
updated_content="$FILE_CONTENT"

# Process each section
chart_num=1
for i in "${!chart_sections[@]}"; do
    chart_section="${chart_sections[$i]}"

    # Skip empty sections
    if [[ -z "$(echo "$chart_section" | grep -v '^[[:space:]]*$' | grep -v '^#')" ]]; then
        continue
    fi

    if [ $total_charts -gt 1 ]; then
        section "Chart $chart_num/$total_charts"
    fi

    # Clear variables from previous iteration
    unset REPO VERS CHART

    # Source the section content
    eval "$chart_section"

    # Validate required variables
    if [ -z "${REPO:-}" ]; then
        warn "Skipping section $chart_num: REPO variable not found"
        ((chart_num++))
        echo ""
        continue
    fi

    if [ -z "${VERS:-}" ]; then
        warn "Skipping section $chart_num: VERS variable not found"
        ((chart_num++))
        echo ""
        continue
    fi

    info "Repository: $REPO"
    info "Current Version: $VERS"
    if [ -n "${CHART:-}" ]; then
        info "Chart: $CHART"
    fi
    echo ""

    # Determine target version
    latest_version=""
    if [ -n "$TARGET_VERSION" ]; then
        # User specified a target version
        latest_version="$TARGET_VERSION"
        info "Target Version: $latest_version"
    else
        # Query for latest version
        if [[ "$REPO" == oci://* ]]; then
            latest_version=$(get_latest_oci_version "$REPO" "$VERS")
        else
            if [ -z "${CHART:-}" ]; then
                chart_name=$(basename "$REPO")
                warn "CHART not specified, using extracted name: $chart_name"
            else
                chart_name="$CHART"
            fi
            latest_version=$(get_latest_helm_version "$REPO" "$chart_name" "$VERS")
        fi
        info "Latest Version: $latest_version"
    fi

    # Compare versions and determine if we should update
    if [ "$latest_version" != "$VERS" ]; then
        # Determine the action based on whether user specified a version
        action_message=""
        should_update=false

        if [ -n "$TARGET_VERSION" ]; then
            # User specified a target version - allow both upgrades and downgrades
            should_update=true
            if version_less_than "$VERS" "$latest_version"; then
                action_message="✓ Upgrade: $VERS -> $latest_version"
            else
                action_message="✓ Downgrade: $VERS -> $latest_version"
            fi
        else
            # Auto-discovery mode - only allow upgrades
            if version_less_than "$VERS" "$latest_version"; then
                should_update=true
                action_message="✓ Update available: $VERS -> $latest_version"
            else
                info "Current version ($VERS) is newer than latest stable ($latest_version)"
            fi
        fi

        if [ "$should_update" = true ]; then
            info "$action_message"

            # Prepare update
            updates+=("$REPO: $VERS -> $latest_version")

            # Update the content by replacing the version
            # We need to be careful to only replace the specific VERS line for this chart
            updated_content=$(echo "$updated_content" | awk -v old_vers="$VERS" -v new_vers="$latest_version" '
                /^VERS=/ {
                    if ($0 == "VERS=" old_vers) {
                        print "VERS=" new_vers
                        next
                    }
                }
                { print }
            ')
        fi
    else
        info "Already at target version"
    fi

    ((chart_num++))
    echo ""
done

# Summary
echo ""
section "Summary"

if [ ${#updates[@]} -eq 0 ]; then
    info "No updates available"
    exit 0
else
    info "Found ${#updates[@]} update(s):"
    for update in "${updates[@]}"; do
        echo -e "  ${GREEN}•${NC} $update"
    done
    echo ""

    if [ "$DRY_RUN" = true ]; then
        dry_run_info "The following changes would be made to $CONFIG_FILE_ABS:"
        echo ""
        echo "--- Current"
        echo "+++ Proposed"
        diff -u "$CONFIG_FILE_ABS" <(echo "$updated_content") || true
        exit 0
    else
        info "Updating $CONFIG_FILE_ABS..."
        echo "$updated_content" > "$CONFIG_FILE_ABS"
        info "✓ Config file updated successfully!"

        # Auto-download charts if requested
        if [ "$AUTO_DOWNLOAD" = true ]; then
            echo ""
            section "Auto-downloading Charts"

            # Get the script directory to find download-helm-chart.sh
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            DOWNLOAD_SCRIPT="$SCRIPT_DIR/download-helm-chart.sh"

            if [ -f "$DOWNLOAD_SCRIPT" ]; then
                info "Running: $DOWNLOAD_SCRIPT $CONFIG_FILE_ABS"
                echo ""

                if "$DOWNLOAD_SCRIPT" "$CONFIG_FILE_ABS"; then
                    info "✓ Charts downloaded successfully!"
                else
                    warn "Chart download failed with exit code $?"
                fi
            else
                warn "Download script not found at: $DOWNLOAD_SCRIPT"
                warn "Skipping automatic chart download"
            fi
        fi
    fi
fi

echo ""
