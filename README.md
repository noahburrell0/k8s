# Hello Akuity 👋

## What is this repository?

This repository is where I keep the configurations for my personal homelab. I've added in a guestbook application and Prometheus/Alertmanager/Grafana for this technical challenge.

## Grafana

I've made Grafana externally accessible for this technical challenge, you can view it here: https://grafana.akuity.burrell.tech/

The Argo CD dashboard can be directly accessed at this URL: https://grafana.akuity.burrell.tech/d/LCAgc9rWz/argocd?orgId=1

**Username:** `admin`

**Password:** `prom-operator`

## Guestbook

I've also deployed a guestbook application, it is externally accessible here: https://guestbook.akuity.burrell.tech/

## Where is everything?

### Application and project definitions

You can find the application and project definitions for Argo CD in [argocd](argocd), the guestbook and prometheus applications are located in [argocd/applications/akuity](argocd/applications/akuity).

The app-of-apps is here: [argocd/app-of-apps.yaml](argocd/app-of-apps.yaml)

### Configurations

All manifests, Helm values, etc., are located in [configs](configs). You can check the [configs/akuity](configs/akuity) directory for the guestbook and Prometheus/Alertmanager/Grafana configurations.

## Self-Managing Argo CD

Part of the requirements outlined "a self-managed Argo CD" instance. I wasn't sure if this meant self-hosted (ie. not using the Akuity or Codefresh type of hosted offerings), or if it meant that Argo CD should be self-managing.

Regardless, I already have a self-managing Argo CD instance. Any changes I make to Argo CD's configurations will automatically be applied by Argo CD once committed without the need to manually issue a `kubectl` command.

The application definition is here: [argocd/applications/setup/argocd.yaml](argocd/applications/setup/argocd.yaml)

And Argo CD's configurations are here: [configs/setup/argocd](configs/setup/argocd)


## Alerting

### Prometheus/Alertmanager/Grafana

The monitoring stack is installed using the prometheus-community `kube-prometheus-stack` Helm chart. The values I used are here [configs/akuity/prometheus/values.yaml](configs/akuity/prometheus/values.yaml).

In addition to the values file, the additional configurations I used to enable email alerting and the Argo CD Grafana dashboard are available here [configs/akuity/prometheus/configs](configs/akuity/prometheus/configs)

### Argo CD notifications

Alerts are fired by Argo CD notifications to Alertmanager. The configurations for Argo CD notifications can be found at [configs/setup/argocd/overlay/argocd-install.yaml#L70](configs/setup/argocd/overlay/argocd-install.yaml#L70)

The alerts that can be triggered are based on the following application conditions:
- On deployment (application is synced and healthy)
- On degraded
- On sync failure
- On sync status unknown
- On sync status outofsync

In addition to the alerts fired by Argo CD, the standard set of rules/alerts Prometheus ships with are also enabled. I have not configured any additional Prometheus rules to cover Argo CD specifically.

### Alert delivery

All alerts that go though Alertmanager are configured to be delivered by email (to noah+alerting@burrell.tech) though my [SMTP relay](configs/internal/smtp).







<!-- # Self-Managing Kubernetes Homelab w/ ArgoCD

This repository serves as the immutable source of configurations for my personal homelab and is deployed using ArgoCD. The configurations contained in the repository self-manage ArgoCD as well as the applications. With various operators like external-dns, cert-manager, and metallb, this homelab pretty much manages itself. Once set up, there is zero intervention required to keep things running.

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

![App Status](https://api.burrell.tech/api/badge?name=app-of-apps&revision=true) [`app-of-apps`](argocd/app-of-apps.yaml)

### Setup

- ![App Status](https://api.burrell.tech/api/badge?name=argocd&revision=true) [`argocd`](https://argoproj.github.io/cd/) - The GitOps operator responsible for managing the cluster
- ![App Status](https://api.burrell.tech/api/badge?name=cert-manager&revision=true) [`cert-manager`](https://cert-manager.io/) - Automatic SSL certificate generation, configured for Cloudflare
- ![App Status](https://api.burrell.tech/api/badge?name=external-dns&revision=true) [`external-dns`](https://github.com/kubernetes-sigs/external-dns) - Automatically create DNS entries, configured for Lets Encrypt
- ![App Status](https://api.burrell.tech/api/badge?name=k8s-gateway&revision=true) [`k8s-gateway`](https://github.com/ori-edge/k8s_gateway) - CoreDNS controller plugin
- ![App Status](https://api.burrell.tech/api/badge?name=metacontroller&revision=true) [`metacontroller`](https://metacontroller.github.io/metacontroller/intro.html) - For rapid prototyping an deployment of custom controllers
- ![App Status](https://api.burrell.tech/api/badge?name=metallb&revision=true) [`metallb`](https://metallb.universe.tf/) - A loadbalancer for non-cloud deployments
- ![App Status](https://api.burrell.tech/api/badge?name=metrics-server&revision=true) [`metrics-server`](https://github.com/kubernetes-sigs/metrics-server) - Reports resource usage when running `kubectl top`
- ![App Status](https://api.burrell.tech/api/badge?name=nfs-subdir-provisioner&revision=true) [`nfs-subdir-provisioner`](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) - Automatically provisions subdirectories against an NFS share
- ![App Status](https://api.burrell.tech/api/badge?name=nginx-ingress&revision=true) [`nginx-ingress`](https://github.com/kubernetes/ingress-nginx) - The ingress controller for the cluster (Offical Kubernetes Ingress)
- ![App Status](https://api.burrell.tech/api/badge?name=sealed-secrets&revision=true) [`sealed-secrets`](https://github.com/bitnami-labs/sealed-secrets) - A controller for encrypting and decrypting secrets
- ![App Status](https://api.burrell.tech/api/badge?name=tnsr-controller&revision=true) [`tnsr-controller`](https://github.com/noahburrell0/tnsr-controller)- A homebrew controller that automatically adds firewall and NAT rules

### External

- ![App Status](https://api.burrell.tech/api/badge?name=chia-node&revision=true) [`chia-node`](https://github.com/Chia-Network/chia-docker) - A Chia node for the Chia cryptocurrency
- ![App Status](https://api.burrell.tech/api/badge?name=contact-api&revision=true) [`contact-api`](https://github.com/noahburrell0/contact-api) - A small API to submit form data from my website to an SMTP relay
- ![App Status](https://api.burrell.tech/api/badge?name=ghost&revision=true) [`ghost`](https://ghost.org/) - Blogging software
- ![App Status](https://api.burrell.tech/api/badge?name=main-site&revision=true) [`main-site`](https://github.com/noahburrell0/burrell-tech) - Combines the Bitnami Nginx and Error Pages charts to deploy my website
- ![App Status](https://api.burrell.tech/api/badge?name=minio&revision=true) [`minio`](https://min.io/) - An S3 compliant object storage system
- ![App Status](https://api.burrell.tech/api/badge?name=ombi&revision=true) [`ombi`](https://ombi.io/) - A multimedia request platform for Plex
- ![App Status](https://api.burrell.tech/api/badge?name=paperless&revision=true) [`paperless`](https://docs.paperless-ngx.com/) - A document management system
- ![App Status](https://api.burrell.tech/api/badge?name=plex&revision=true) [`plex`](https://www.plex.tv/) - A multimedia server
- ![App Status](https://api.burrell.tech/api/badge?name=seafile&revision=true) [`seafile`](https://www.seafile.com/) - Self-hosted cloud storage system

### Internal

- ![App Status](https://api.burrell.tech/api/badge?name=nzbget&revision=true) [`nzbget`](https://nzbget.net/) - A Usenet download platform
- ![App Status](https://api.burrell.tech/api/badge?name=radarr&revision=true) [`radarr`](https://radarr.video/) - Automatically search, download, and manage movies
- ![App Status](https://api.burrell.tech/api/badge?name=sonarr&revision=true) [`sonarr`](https://sonarr.tv/) - Automatically search, download, and manage television series
- ![App Status](https://api.burrell.tech/api/badge?name=smtp&revision=true) [`smtp`](https://github.com/djjudas21/smtp-relay) - A local SMTP relay to centralize a point in the cluster from which to send emails
- ![App Status](https://api.burrell.tech/api/badge?name=tdarr&revision=true) [`tdarr`](https://tdarr.io/) - An automatic multimedia transcoder
- ![App Status](https://api.burrell.tech/api/badge?name=unifi&revision=true) [`unifi`](https://www.ui.com/download/unifi/) - The Uniquiti Unifi controller for managing Ubiquiti network devices

## Bootstrapping

ArgoCD needs to be manually bootstrapped before it can self-manage. The only pre-requisite is a Kubernetes cluster with a CNI installed. All other required components will be install after bootstrapping.

```
kubectl apply -k configs/setup/argocd/
kubectl apply -f argocd/app-of-apps.yaml -n argocd
```

The above commands will deploy ArgoCD and the `app-of-apps` application which will be used to discover and deploy all other applications out of this repository. From this point forward, ArgoCD will also self-manage. Any updates to `configs/setup/argocd/` will be automatically discovered and applied.

## Secrets

All secrets are encrypted and stored in this repository using [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) by Bitnami. Only I hold the decryption keys for the secrets in this repository. If you are using this repository as the basis for you own homelab or Kubernetes cluster, be aware that none of the sealed secrets here will unseal for you. You will need seal your own secrets and replace mine. As a result, if you try to deploy the applications contained in this repository using my configurations, the application will most likely be broken.

---

# Hire Me!

Need help getting started with Kubernetes (or DevOps, or GitOps), or have a project you need an extra set of hands with? I'm available for freelance and consulting work! I'm a CKA certified Kubernetes (and Linux) administrator and DevOps engineer during the day in the financial services industry, and I also do a lot of the same sort of stuff in my spare time for fun.

Email me directly at [noah@burrell.tech](mailto:noah@burrell.tech), or visit my website at [burrell.tech](https://burrell.tech). -->
