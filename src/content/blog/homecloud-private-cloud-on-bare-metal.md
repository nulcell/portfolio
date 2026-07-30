---
title: 'homecloud: a private "cloud" on bare metal'
description: 'Why I run a Kubernetes cluster at home - Talos, Cilium, ArgoCD, and the security stack that watches over it.'
date: 2026-07-29
tags: ['homelab', 'kubernetes', 'security', 'talos', 'cilium', 'argo', 'cloudflare', 'falco']
---

The site you're reading right now is not on Vercel, Netlify, or a $5 VPS.
It's running on [homecloud](https://github.com/nulcell/homecloud), a
Kubernetes cluster on bare metal in my home (in a random spot), reached through a Cloudflare
tunnel. This post is a tour of what's in it and why I bother.

## Why run a cluster at home?

Two reasons. First, the honest one: it's fun. Second, the professional one:
I secure cloud infrastructure for a living, and there is no better way to
understand a platform than to operate one end to end. All the networking, storage,
identity, secrets, monitoring, and the inevitable 2am debugging session when
a node decides it's done.

A homelab gives you production-shaped problems with hobby-sized blast
radius.

## The foundation

The cluster runs [Talos Linux](https://www.talos.dev/), an immutable,
API-driven OS built for Kubernetes. No SSH, no shell, no package manager;
you talk to it over an API and everything is declarative. The image is baked
at [Image Factory](https://factory.talos.dev/) as a Secure Boot installer
with the system extensions I need (`iscsi-tools`, `util-linux-tools`,
microcode, `amdgpu`), extensions are chosen at install time, so adding one
later means an OS upgrade. Machine config lives as patches in the repo;
nothing is hand-edited on the node.

Topology today is deliberately honest: **one control-plane node with
scheduling enabled**, Longhorn replica count 1, etcd quorum of 1. The plan
is to jump straight from 1 to 3 control planes when the hardware arrives.

Above the OS:

- **[Cilium](https://cilium.io/)** as the CNI, replacing kube-proxy, and
  also doing Gateway API and L2 announcements. No MetalLB, no separate
  ingress controller.
- **[ArgoCD](https://argoproj.github.io/cd/)** as the source of truth. A
  root Application points at five ApplicationSets (infrastructure,
  operators, services, security, apps) each generating one Application per
  directory, ordered by sync wave so the platform is up before the things
  that depend on it.
- **[Longhorn](https://longhorn.io/)** for replicated block storage,
  **[CNPG](https://cloudnativepg.io/)** for per-app Postgres clusters, a
  MariaDB operator where an app insists on MySQL, and
  **[KubeVirt](https://kubevirt.io/)** + CDI for the workloads that still
  want to be VMs.

Only Cilium and ArgoCD are installed imperatively by a bootstrap script.
Everything else, cert-manager, Longhorn, monitoring, gateways, and every
workload, is GitOps from the first reconcile.

## Secrets: from SOPS to a secret store

The repo started with [SOPS](https://github.com/getsops/sops) + age:
encrypted `.enc.yaml` files committed to git, decrypted by ArgoCD on sync.
It worked, but rotating anything meant re-encrypting and committing, and the
same values already lived in my password manager.

So secrets moved to the **External Secrets Operator** with a
`ClusterSecretStore` backed by 1Password. Manifests now reference a vault
item by name; ESO materialises the Kubernetes Secret and refreshes it on a
schedule. Nothing sensitive is in git at all and the SOPS setup is parked in
`experimental/` in case I want it back for air-gapped material.

## Getting traffic in

Two Cilium Gateways: `external` and `internal`, the latter carrying an
extra `*.internal.nulcell.com` listener. cert-manager issues a single
wildcard certificate covering the apex, `*.nulcell.com`, and
`*.internal.nulcell.com` from Let's Encrypt via Cloudflare **DNS-01**, no
port 80 challenge, so nothing has to be publicly reachable to get a cert.
external-dns writes the records.

Anything public goes out through **cloudflared**. The tunnel forwards a
public hostname to the internal gateway service inside the cluster and
rewrites the Host header to the matching `*.internal` name, so the same
HTTPRoute serves both paths. A post-sync Job runs
`cloudflared tunnel route dns` for each hostname, which means adding a
public service is a values entry rather than a click in the Cloudflare
dashboard.

The result: no ports open on my router, no home IP in public DNS. For
administrative access there's a Tailscale operator in-cluster, and Tailscale
on the Raspberry Pi that handles netboot and DNS.

## The security stack

This is the part I care most about, the cluster doubles as a lab for
tooling I evaluate professionally.

**[Falco](https://falco.org/)** runs with the modern eBPF driver, loading
both the syscall rules and the `k8saudit` plugin. Talos writes API server
audit logs to disk; a small Fluent Bit daemonset tails them and posts them
into Falco's audit webhook, so runtime syscall detections and control-plane
audit detections land in the same engine. `falcoctl` keeps the rule sets
updated.

Alerts flow into **Falcosidekick**, which forwards anything `error` or
above to Alertmanager and to **[Falco Talon](https://docs.falco-talon.org/)**,
the response engine. Talon can terminate or isolate a pod on a matching detection and record a
Kubernetes event. Automated response in a homelab is low-stakes enough to
actually experiment with.

Trivy Operator and Kubescape have both had a run in this cluster, image
scanning, SBOMs, exposed-secret detection, RBAC assessment, CIS/NSA posture
reports. Both are currently parked in the experimental tree: on a
single node they cost more CPU than the signal was worth, and Kubescape's
operator queue does not enjoy Trivy's ephemeral scan jobs. They come back
when there are more nodes to spread them across.

## Observability

kube-prometheus-stack for metrics, **Grafana Loki** for logs, with
**Grafana Alloy** shipping pod logs via the Kubernetes API with no host volume
mounts, and infrastructure namespaces dropped at the relabel stage so I'm
not paying to store my own platform's chatter. Headlamp runs in-cluster for
the times a dashboard beats `kubectl` (but I end up using k9s most of the time).

## What actually runs on it

The live list is on the [status page](https://status.nulcell.com/status/services)
(Uptime Kuma), also running in the cluster, which is either good practice or
a conflict of interest depending on how the day is going. Roughly three
groups:

- **Apps**: [Authentik](https://goauthentik.io/) for identity,
  [n8n](https://n8n.io/) for workflow automation,
  [Outline](https://www.getoutline.com/) as a wiki, Actual Budget, and a
  Homarr dashboard tying them together.
- **Media**: Jellyfin, Seerr, Sonarr, Radarr, Prowlarr, and qBittorrent
  behind a Gluetun VPN sidecar.
- **Internal**: ArgoCD, Grafana, Headlamp, Longhorn, and a speedtest
  tracker that exists mostly so I have receipts when the ISP disappoints me.

Chart and image versions are handled by Renovate, which opens PRs against
the repo every few hours; local CLI versions are pinned with
[mise](https://mise.jdx.dev) so a fresh laptop is one command away from
being able to operate the cluster.

## What's next

The roadmap has more items than free evenings. In rough priority: **backups**
(etcd and Longhorn to S3, the cluster is one node away from losing things I
would **not** miss), the 3-node HA control plane and a 2.5GbE upgrade to go with it,
a proper device plugin so Jellyfin can reach the iGPU without
`privileged: true`, policy enforcement with Kyverno, and Knative plus
RabbitMQ for event-driven workloads.

If any of this sounds interesting, the whole setup is public at
[nulcell/homecloud](https://github.com/nulcell/homecloud) with configs,
manifests, mistakes, and all.
