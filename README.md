# nulcell.com

Personal portfolio and blog for [Salimon Oluwatoyin Ayanleye](https://nulcell.com) -
Astro static site, served by nginx, deployed on the
[homecloud](https://github.com/nulcell/homecloud) Kubernetes cluster at
`nulcell.com`, `www.nulcell.com`, and/or `me.nulcell.com`.

## Stack

- [Astro](https://astro.build) - about page + markdown blog (content collection in `src/content/blog/`)
- bun 1.3 for install/build, pinned via [mise](https://mise.jdx.dev)
- `oven/bun:1.3-alpine` builder → `nginxinc/nginx-unprivileged:1.31-alpine-slim` runtime
- Helm chart in `chart/` (Deployment, Service, Gateway API HTTPRoute or Ingress)
- GitHub Actions → multi-arch (amd64 + arm64) image on Docker Hub (`nullcell/portfolio`)

## Common commands

```bash
mise install            # install pinned tools (bun, helm)
mise run install        # install site dependencies
mise run dev            # Astro dev server
mise run build          # build static site to dist/
mise run stack:up       # build + run the container locally (docker compose)
mise run helm:lint      # lint the chart
mise run ci             # full CI pipeline (build + chart lint)
```

## Writing a post

Drop a markdown file in `src/content/blog/`:

```markdown
---
title: 'Post title'
description: 'One-line summary shown in lists and meta tags.'
date: 2026-07-29
tags: ['kubernetes', 'security']
draft: false
---

Content here.
```

The filename becomes the URL: `my-post.md` → `/blog/my-post/`.

## Releases

CI builds the site and lints the chart on every push and PR. Pushing a
version tag publishes the image:

```bash
git tag v1.0.0 && git push --tags
# → docker.io/nullcell/portfolio:1.0.0 + :latest (linux/amd64 + linux/arm64)
```

Requires `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as GitHub Actions
secrets (already available if the repo runs self-hosted runners on the
cluster with those secrets configured).

## Deploying

The chart contents in `chart/` are intended to be moved into the homecloud
GitOps repo. On homecloud, enable the Gateway API route:

```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: <your-gateway>
      namespace: <gateway-namespace>
```

With neither `httpRoute` nor `ingress` enabled, the chart only creates the
Deployment + Service - fine when a Cloudflare tunnel points straight at the
Service.
