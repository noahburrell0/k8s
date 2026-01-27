# GitOps Kubernetes Homelab

A fully GitOps-managed Kubernetes homelab running on Talos Linux and deployed with ArgoCD. This repository contains all cluster configurations and application deployments, enabling complete infrastructure-as-code management with automated reconciliation.

## Architecture

**Cluster Platform:** Talos Linux with Omni management
**GitOps Engine:** ArgoCD (self-managing)
**Storage:** Longhorn distributed block storage
**Networking:** MetalLB load balancer, NGINX Ingress
**DNS & Certificates:** External-DNS + cert-manager with Cloudflare integration

Applications are organized into ArgoCD projects:

- **`setup`** - Core infrastructure components
  - Definitions: [argocd/applications/setup](argocd/applications/setup)
  - Configs: [configs/setup/](configs/setup/)
- **`external`** - Public-facing applications
  - Definitions: [argocd/applications/external](argocd/applications/external)
  - Configs: [configs/external/](configs/external/)
- **`internal`** - Internal-only services
  - Definitions: [argocd/applications/internal](argocd/applications/internal)
  - Configs: [configs/internal/](configs/internal/)
- **`private`** - Private applications (separate repository)

## Applications

- ![App Status](https://api.burrell.tech/api/badge?name=app-of-apps&revision=true) [app-of-apps](argocd/app-of-apps.yaml) - Automated discovery of other Applications

### Setup Infrastructure

- ![App Status](https://api.burrell.tech/api/badge?name=argocd&revision=true) [argocd](https://argoproj.github.io/cd/) - GitOps continuous delivery
- ![App Status](https://api.burrell.tech/api/badge?name=cert-manager&revision=true) [cert-manager](https://cert-manager.io/) - Automated certificate management with Let's Encrypt
- ![App Status](https://api.burrell.tech/api/badge?name=external-dns&revision=true) [external-dns](https://github.com/kubernetes-sigs/external-dns) - Automated DNS record management via Cloudflare
- ![App Status](https://api.burrell.tech/api/badge?name=external-secrets&revision=true) [external-secrets](https://external-secrets.io/) - External secret management integration
- ![App Status](https://api.burrell.tech/api/badge?name=k8s-gateway&revision=true) [k8s-gateway](https://github.com/ori-edge/k8s_gateway) - DNS gateway for ingress resources
- ![App Status](https://api.burrell.tech/api/badge?name=longhorn&revision=true) [longhorn](https://longhorn.io/) - Distributed block storage
- ![App Status](https://api.burrell.tech/api/badge?name=metallb&revision=true) [metallb](https://metallb.universe.tf/) - Bare metal load balancer
- ![App Status](https://api.burrell.tech/api/badge?name=metrics-server&revision=true) [metrics-server](https://github.com/kubernetes-sigs/metrics-server) - Resource metrics collection
- ![App Status](https://api.burrell.tech/api/badge?name=nginx-ingress&revision=true) [nginx-ingress](https://github.com/kubernetes/ingress-nginx) - Ingress controller
- ![App Status](https://api.burrell.tech/api/badge?name=sealed-secrets&revision=true) [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) - Encrypted secrets management

### External Services

- ![App Status](https://api.burrell.tech/api/badge?name=contact-api&revision=true) [contact-api](https://github.com/noahburrell0/contact-api) - Website contact form API
- ![App Status](https://api.burrell.tech/api/badge?name=harbor&revision=true) [harbor](https://goharbor.io/) - Container registry
- ![App Status](https://api.burrell.tech/api/badge?name=home-assistant&revision=true) [home-assistant](https://www.home-assistant.io/) - Home automation platform
- ![App Status](https://api.burrell.tech/api/badge?name=main-site&revision=true) [main-site](https://github.com/noahburrell0/burrell-tech) - Personal website
- ![App Status](https://api.burrell.tech/api/badge?name=minio-1&revision=true) [minio](https://min.io/) - S3-compatible object storage
- ![App Status](https://api.burrell.tech/api/badge?name=seafile&revision=true) [seafile](https://www.seafile.com/) - File sync and share platform

### Internal Services

- ![App Status](https://api.burrell.tech/api/badge?name=bazarr&revision=true) [bazarr](https://www.bazarr.media/) - Subtitle management for Radarr/Sonarr
- ![App Status](https://api.burrell.tech/api/badge?name=nzbget&revision=true) [nzbget](https://nzbget.net/) - Usenet downloader
- ![App Status](https://api.burrell.tech/api/badge?name=paperless&revision=true) [paperless](https://docs.paperless-ngx.com/) - Document management system
- ![App Status](https://api.burrell.tech/api/badge?name=radarr&revision=true) [radarr](https://radarr.video/) - Movie collection manager
- ![App Status](https://api.burrell.tech/api/badge?name=shinobi&revision=true) [shinobi](https://shinobi.video/) - Video surveillance platform
- ![App Status](https://api.burrell.tech/api/badge?name=smtp&revision=true) [smtp](https://github.com/djjudas21/smtp-relay) - SMTP relay service
- ![App Status](https://api.burrell.tech/api/badge?name=sonarr&revision=true) [sonarr](https://sonarr.tv/) - TV series collection manager
- ![App Status](https://api.burrell.tech/api/badge?name=tdarr&revision=true) [tdarr](https://tdarr.io/) - Media transcoding automation

## Cluster Provisioning

The cluster runs on Talos Linux and is managed via Omni. Cluster configuration and machine provisioning is defined in [omni/cluster.yaml](omni/cluster.yaml).

**Key cluster/lab features:**
- Talos Linux v1.11.6
- Kubernetes v1.34.1
- Omni/Proxmox automatic node provisioner
- Longhorn distributed storage

## Bootstrapping ArgoCD

After cluster provisioning, bootstrap ArgoCD to enable GitOps management:

```bash
kubectl apply -k configs/setup/argocd/
kubectl apply -f argocd/app-of-apps.yaml -n argocd
```

This deploys ArgoCD and the app-of-apps pattern, which automatically discovers all applications in this repository. Before the ArgoCD UI becomes accessible, critical infrastructure applications must be synced using the ArgoCD CLI in core mode:

```bash
# Switch to argocd namespace
kubectl config set-context --current --namespace=argocd

# Sync critical infrastructure components
argocd app sync metallb --core
argocd app sync nginx-ingress --core
argocd app sync cert-manager --core
argocd app sync external-secrets --core
```

Once these core components are deployed, the ArgoCD UI becomes accessible. Remaining applications can be reviewed and synced through the UI. ArgoCD becomes self-managing - any configuration changes are automatically reconciled.

## Secret Management

This repository uses a two-tier secret management strategy:

1. **Bootstrap Secrets** - [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) is used only for initial cluster bootstrapping and ArgoCD setup
2. **Runtime Secrets** - [external-secrets](https://external-secrets.io/) handles all application secrets after bootstrapping, integrating with external secret providers

**Note:** Sealed secrets in this repository are encrypted for this specific cluster. To use this configuration in your own environment, deploy sealed-secrets with your own keys and configure external-secrets for your secret backend.

## Repository Structure

```
.
├── argocd/
│   ├── app-of-apps.yaml            # Root ArgoCD application
│   ├── applications/               # ArgoCD app definitions
│   │   ├── setup/                  # Infrastructure apps
│   │   ├── external/               # Public-facing apps
│   │   └── internal/               # Internal apps
│   └── projects/                   # ArgoCD project definitions
│       ├── setup.yaml              # Infrastructure project
│       ├── external.yaml           # External apps project
│       ├── internal.yaml           # Internal apps project
│       └── private.yaml            # Private apps project
├── configs/
│   ├── setup/                      # Infrastructure configurations
│   ├── external/                   # External app configurations
│   └── internal/                   # Internal app configurations
├── omni/
│   ├── cluster.yaml                # Talos cluster definition (Omni)
│   ├── omni/                       # Self-hosted Omni setup
│   │   └── compose.yaml            # Omni on-prem deployment
│   └── proxmox-provider/           # Proxmox infrastructure provider
│       ├── compose.yaml            # Provider service
│       ├── config.yaml             # Proxmox configuration
│       └── machineclass.yaml       # Machine class definitions
└── hack/                           # Helper scripts
    ├── download-helm-chart.sh      # Download Helm charts
    └── bump-chart-version.sh       # Update chart versions
```

