# Self-Managing Kubernetes Homelab w/ ArgoCD

This repository serves as the immutable source of configurations for my personal homelab and are deployed using ArgoCD. The configurations contained in the repository self-manage the ArgoCD as well as the applications.

Applications are divided into ArgoCD projects by their respective types.

- `setup` - Required base components used to operate the cluster and deployments.
  - ArgoCD Application Definitions: `argocd/applications/setup`
  - Configurations: `configs/setup/`
- `external` - Externally facing applications.
  - ArgoCD Application Definitions: `argocd/applications/external`
  - Configurations: `configs/external/`
- `internal` - Internal-only applications.
  - ArgoCD Application Definitions: `argocd/applications/internal`
  - Configurations: `configs/internal/`

## Applications

![App Status](https://app-status.burrell.tech/api/badge?name=app-of-apps&revision=true) [`app-of-apps`](argocd/app-of-apps.yaml)

### Setup

- ![App Status](https://app-status.burrell.tech/api/badge?name=argocd&revision=true) [`argocd`](https://argoproj.github.io/cd/) - The GitOps operator responsible for managing the cluster
- ![App Status](https://app-status.burrell.tech/api/badge?name=cert-manager&revision=true) [`cert-manager`](https://cert-manager.io/) - Automatic SSL certificate generation, configured for Cloudflare
- ![App Status](https://app-status.burrell.tech/api/badge?name=external-dns&revision=true) [`external-dns`](https://github.com/kubernetes-sigs/external-dns) - Automatically create DNS entries, configured for Lets Encrypt
- ![App Status](https://app-status.burrell.tech/api/badge?name=k8s-gateway&revision=true) [`k8s-gateway`](https://github.com/ori-edge/k8s_gateway) - CoreDNS based controller to act as a secondary DNS zone
- ![App Status](https://app-status.burrell.tech/api/badge?name=metacontroller&revision=true) [`metacontroller`](https://metacontroller.github.io/metacontroller/intro.html) - For rapid prototyping an deployment of custom controllers
- ![App Status](https://app-status.burrell.tech/api/badge?name=metallb&revision=true) [`metallb`](https://metallb.universe.tf/) - A loadbalancer for non-cloud deployments
- ![App Status](https://app-status.burrell.tech/api/badge?name=metrics-server&revision=true) [`metrics-server`](https://github.com/kubernetes-sigs/metrics-server) - Reports resource usage when running `kubectl top`
- ![App Status](https://app-status.burrell.tech/api/badge?name=nfs-subdir-provisioner&revision=true) [`nfs-subdir-provisioner`](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) - Automatically provisions subdirectories against an NFS share
- ![App Status](https://app-status.burrell.tech/api/badge?name=nginx-ingress&revision=true) [`nginx-ingress`](https://github.com/kubernetes/ingress-nginx) - The ingress controller for the cluster (Offical Kubernetes Ingress)
- ![App Status](https://app-status.burrell.tech/api/badge?name=sealed-secrets&revision=true) [`sealed-secrets`](https://github.com/bitnami-labs/sealed-secrets) - A controller for encrypting and decrypting secrets
- ![App Status](https://app-status.burrell.tech/api/badge?name=tnsr-controller&revision=true) [`tnsr-controller`](https://github.com/noahburrell0/tnsr-controller)- A homebrew controller that automatically adds firewall and NAT rules

### External

- ![App Status](https://app-status.burrell.tech/api/badge?name=chia-node&revision=true) [`chia-node`](https://github.com/Chia-Network/chia-docker) - A Chia node for the Chia cryptocurrency
- ![App Status](https://app-status.burrell.tech/api/badge?name=ghost&revision=true) [`ghost`](https://ghost.org/) - Blogging software
- ![App Status](https://app-status.burrell.tech/api/badge?name=main-site&revision=true) [`main-site`](https://github.com/noahburrell0/burrell-tech) - Combines the Bitnami Nginx and Error Pages charts to deploy my website
- ![App Status](https://app-status.burrell.tech/api/badge?name=minio&revision=true) [`minio`](https://min.io/) - An S3 compliant object storage system
- ![App Status](https://app-status.burrell.tech/api/badge?name=ombi&revision=true) [`ombi`](https://ombi.io/) - A multimedia request platform for Plex
- ![App Status](https://app-status.burrell.tech/api/badge?name=paperless&revision=true) [`paperless`](https://docs.paperless-ngx.com/) - A document management system
- ![App Status](https://app-status.burrell.tech/api/badge?name=plex&revision=true) [`plex`](https://www.plex.tv/) - A multimedia server 
- ![App Status](https://app-status.burrell.tech/api/badge?name=seafile&revision=true) [`seafile`](https://www.seafile.com/) - Self-hosted cloud storage system

### Internal

- ![App Status](https://app-status.burrell.tech/api/badge?name=nzbget&revision=true) [`nzbget`](https://nzbget.net/) - A Usenet download platform
- ![App Status](https://app-status.burrell.tech/api/badge?name=radarr&revision=true) [`radarr`](https://radarr.video/) - Automatically search, download, and manage movies
- ![App Status](https://app-status.burrell.tech/api/badge?name=sonarr&revision=true) [`sonarr`](https://sonarr.tv/) - Automatically search, download, and manage television series
- ![App Status](https://app-status.burrell.tech/api/badge?name=smtp&revision=true) [`smtp`](https://github.com/djjudas21/smtp-relay) - A local SMTP relay to centralize a point in the cluster from which to send emails
- ![App Status](https://app-status.burrell.tech/api/badge?name=tdarr&revision=true) [`tdarr`](https://tdarr.io/) - An automatic multimedia transcoder
- ![App Status](https://app-status.burrell.tech/api/badge?name=unifi&revision=true) [`unifi`](https://www.ui.com/download/unifi/) - The Uniquiti Unifi controller for managing Ubiquiti network devices

## Bootstrapping

ArgoCD needs to be manually bootstrapped before it can self-manage. The only pre-requisite is a Kubernetes cluster with a CNI installed. All other required components will be install after bootstrapping.

```
kubectl apply -k configs/setup/argocd/
kubectl apply -f argocd/app-of-apps.yaml -n argocd
```

The above commands will deploy ArgoCD and the `app-of-apps` application which will be used to discover and deploy all other applications out of this repository. From this point forward, ArgoCD will also self-manage. Any updates to `configs/setup/argocd/` will be automatically discovered and applied.

## Secrets

All secrets are encrypted and stored in this repository using [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) by Bitnami. Only I hold the decryption keys for the secrets in this repository. If you are using this repository as the basis for you own homelab or Kubernetes cluster, be aware that none of the sealed secrets here will unseal for you. You will need seal your own secrets and replace mine. As a result, if you try to deploy the applications contained in this repository using my configurations, the application will most likely be broken.

## Special Mentions

Most of the applications being deployed rely heavily on Helm Charts and Docker images provided by 3rd parties. It would be a lot more difficult and time consuming to do this without the organizations and projects and maintain these.

### Containers - [onedr0p](https://github.com/onedr0p/containers) 

### Helm Charts - [Kubernetes @Home](https://github.com/k8s-at-home) (Archived) and the new maintainer [bjw-s](https://github.com/bjw-s)

### Helm Charts and Containers - [Bitnami](https://bitnami.com/stacks/helm)

---

# Hire Me!

Need help getting started with Kubernetes (or DevOps, or GitOps), or have a project you need an extra set of hands with? I'm available for freelance and consulting work! I'm a CKA certified Kubernetes (and Linux) administrator and DevOps engineer during the day in the financial services industry, and I also do a lot of the same sort of stuff in my spare time for fun.

## Areas of Expertise

- Kubernetes
- Helm
- ArgoCD
- Docker
- General GitOps/DevOps principles
- Linux system administration
- Enterprise scale networking
- GCP and Azure

## Contact Me

Email me directly at [noah@burrell.tech](mailto:noah@burrell.tech), or visit my website at [burrell.tech](https://burrell.tech). I promise I don't bite.