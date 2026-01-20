#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    echo "Usage: $0 <path-to-config-file> [output-directory]"
    echo ""
    echo "Arguments:"
    echo "  path-to-config-file    Path to .conf file containing chart definitions"
    echo "  output-directory       Optional output directory (default: charts/ next to config file)"
    echo ""
    echo "Behavior:"
    echo "  - Downloads and extracts Helm charts"
    echo "  - Default output: <config-dir>/charts/"
    echo "  - Removes .tgz files after extraction"
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
    echo "Example:"
    echo "  $0 path/to/repo.conf"
    echo "  $0 path/to/repo.conf path/to/charts"
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

# Function to download a single chart
download_chart() {
    local repo="$1"
    local version="$2"
    local chart_name="${3:-}"

    # Detect if this is an OCI repository
    if [[ "$repo" == oci://* ]]; then
        info "Type: OCI Helm chart"
        info "Pulling: $repo version $version"

        if helm pull "$repo" --version "$version"; then
            info "✓ Successfully downloaded"

            # Extract the chart name from the repo URL (last segment)
            local chart_basename=$(basename "$repo")
            local tarball="${chart_basename}-${version}.tgz"

            if [ -f "$tarball" ]; then
                info "Extracting: $tarball"
                if tar -xzf "$tarball"; then
                    info "✓ Successfully extracted"
                    rm -f "$tarball"
                    info "Cleaned up tarball"
                else
                    warn "Failed to extract $tarball"
                fi
            fi
            return 0
        else
            error_exit "Failed to pull OCI chart from $repo"
        fi
    else
        info "Type: Traditional Helm chart"

        # Check if chart name was provided
        if [ -z "$chart_name" ]; then
            # Try to extract chart name from REPO (last segment)
            chart_name=$(basename "$repo")
            warn "CHART not specified, using extracted name: $chart_name"
        fi

        # Add the helm repository temporarily
        local repo_name="temp-repo-$$-$(date +%s)"
        info "Adding repository: $repo_name"

        if helm repo add "$repo_name" "$repo" 2>/dev/null; then
            info "Repository added"
        else
            warn "Repository add warning, continuing..."
        fi

        # Update repositories
        helm repo update "$repo_name" &>/dev/null || true

        # Pull the chart
        info "Pulling: $repo_name/$chart_name version $version"
        if helm pull "$repo_name/$chart_name" --version "$version"; then
            info "✓ Successfully downloaded"

            # Extract the tarball
            local tarball="${chart_name}-${version}.tgz"
            if [ -f "$tarball" ]; then
                info "Extracting: $tarball"
                if tar -xzf "$tarball"; then
                    info "✓ Successfully extracted"
                    rm -f "$tarball"
                    info "Cleaned up tarball"
                else
                    warn "Failed to extract $tarball"
                fi
            fi
        else
            helm repo remove "$repo_name" 2>/dev/null || true
            error_exit "Failed to pull chart $repo_name/$chart_name"
        fi

        # Clean up - remove the temporary repository
        helm repo remove "$repo_name" 2>/dev/null || true
    fi
}

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    error_exit "helm is not installed. Please install helm first."
fi

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

CONFIG_FILE="$1"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Config file not found: $CONFIG_FILE"
fi

# Get absolute path of config file before changing directories
CONFIG_FILE_ABS="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"

# Determine output directory - charts folder next to config file
CONFIG_DIR="$(dirname "$CONFIG_FILE_ABS")"
OUTPUT_DIR="$CONFIG_DIR/charts"

# Allow override via second argument
if [ $# -ge 2 ]; then
    OUTPUT_DIR="$2"
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    info "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Change to output directory
cd "$OUTPUT_DIR"

echo ""
info "Reading configuration from: $CONFIG_FILE_ABS"
info "Output directory: $(pwd)"
echo ""

# Parse the config file and split into sections
# Sections are separated by lines starting with ###
declare -a chart_sections=()
current_section=""

while IFS= read -r line || [ -n "$line" ]; do
    # Check if line starts with ###
    if [[ "$line" =~ ^###[[:space:]]*.* ]]; then
        # Save previous section if it exists
        if [ -n "$current_section" ]; then
            chart_sections+=("$current_section")
        fi
        # Start new section
        current_section=""
    else
        # Append to current section
        if [ -n "$current_section" ]; then
            current_section+=$'\n'
        fi
        current_section+="$line"
    fi
done < "$CONFIG_FILE_ABS"

# Add the last section
if [ -n "$current_section" ]; then
    chart_sections+=("$current_section")
fi

# If no sections found (no ### separators), treat entire file as single chart
if [ ${#chart_sections[@]} -eq 0 ]; then
    chart_sections+=("$(cat "$CONFIG_FILE_ABS")")
fi

total_charts=${#chart_sections[@]}
info "Found $total_charts chart(s) to process"
echo ""

# Process each section
chart_num=1
for chart_section in "${chart_sections[@]}"; do
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
    info "Version: $VERS"
    if [ -n "${CHART:-}" ]; then
        info "Chart: $CHART"
    fi
    echo ""

    download_chart "$REPO" "$VERS" "${CHART:-}"

    ((chart_num++))
    echo ""
done

info "All downloads complete!"
