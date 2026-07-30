---
title: 'How this site is built and shipped'
description: 'Astro to static HTML, one hardened nginx container, multi-arch images, and a Helm chart onto the homelab cluster.'
date: 2026-07-28
tags: ['astro', 'docker', 'kubernetes', 'helm', 'nginx', 'homecloud', 'cloudflare', 'talos']
---

This site is deliberately boring infrastructure, the kind I like. Markdown
in, static HTML out, one small container, deployed like everything else on
my cluster. Here's the whole pipeline.

## The site

[Astro](https://astro.build) builds the pages. The about page is a single
component; blog posts like this one are markdown files in a content
collection with a typed frontmatter schema.

```text
src/
├── pages/          # about, blog index, post template
├── content/blog/   # posts as markdown
├── layouts/        # shared shell (header, footer, theme)
└── styles/         # one CSS file, light/dark via CSS variables
```

## The container

A two-stage build: bun compiles the site, nginx serves it. The runtime image
is `nginx-unprivileged`, it runs as a non-root user on port 8080, with
security headers, a strict CSP, and a `/health` endpoint for probes. The
final image is ~25 MB of alpine plus static files.

```dockerfile
FROM oven/bun:1.3-alpine AS builder
# install, build → dist/

FROM nginxinc/nginx-unprivileged:1.31-alpine-slim
COPY --from=builder /app/dist /usr/share/nginx/html
```

Images are built for both `linux/amd64` and `linux/arm64`, the cluster has
a x86 mini-PCs but my laptop is ARM, so multi-arch manifests mean the
same image can run anywhere (mostly).

## The pipeline

GitHub Actions builds the site on every push and PR as a smoke test. Pushing
a version tag (`v1.2.0`) triggers the release job: buildx builds both
architectures and pushes to Docker Hub tagged with the version and
`latest`.

## The deployment

A small Helm chart  lands it on [homecloud](https://github.com/nulcell/homecloud).
ArgoCD watches the repo and syncs, external-dns publishes relevant records,
cert-manager sorts TLS, and traffic arrives through a Cloudflare tunnel
so nothing at home is directly exposed.

The result: writing a post is `git push`, and shipping a new version is
`git tag`. Anything more would be overengineering, although, given the
cluster it runs on, that ship may have sailed.
