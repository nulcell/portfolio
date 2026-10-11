# nulcell.com

Personal portfolio and blog for [Salimon Oluwatoyin Ayanleye](https://nulcell.com).
It is an Astro static site served by nginx and deployed on the
[homecloud](https://github.com/nulcell/homecloud) Kubernetes cluster at
`nulcell.com`, `www.nulcell.com`, and/or `me.nulcell.com`.

## Stack

- [Astro](https://astro.build) for the about page and the markdown blog (content collection in `src/content/blog/`)
- bun 1.3 for install and build, pinned via [mise](https://mise.jdx.dev)
- `oven/bun:1.3-alpine` builder, `nginxinc/nginx-unprivileged:1.31-alpine-slim` runtime
- GitHub Actions builds a multi-arch (amd64 and arm64) image on Docker Hub (`nullcell/portfolio`)

## Common commands

```bash
mise install            # install pinned tools (bun, node)
mise run install        # install site dependencies
bun dev                 # Astro dev server
bun run preview         # preview the production build
mise run build          # build static site to dist/
mise run ci             # full CI pipeline

# run the real image locally
docker run --rm -p 8080:8080 $(docker build -q .)
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

The filename becomes the URL: `my-post.md` becomes `/blog/my-post/`.

## Releases

CI builds the site on every push and PR. Pushing a
version tag publishes the image:

```bash
git tag v1.0.0 && git push --tags
# publishes docker.io/nullcell/portfolio:1.0.0 and :latest (linux/amd64 and linux/arm64)
```

This needs `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as GitHub Actions
secrets. They are already available if the repo runs self-hosted runners on the
cluster with those secrets configured.

## Deploying

There is no chart in this repo. The [homecloud](https://github.com/nulcell/homecloud)
GitOps repo deploys the image with the `app-template` chart from
[nulcell/charts](https://github.com/nulcell/charts), configured in
[`gitops/apps/portfolio`](https://github.com/nulcell/homecloud/tree/main/gitops/apps/portfolio).
To ship a release, push a version tag, then bump the image tag in that
`values.yaml`.
