# Release procedure

This repository publishes `ghcr.io/ploos-as/gamja` from GitHub Actions.

## Release gate

A release candidate must satisfy all of the following on `main`:

- runtime smoke test passes on linux/amd64
- container runs non-root with a read-only root filesystem
- health check reaches `healthy`
- Gamja `/socket` performs a real WebSocket upgrade through nginx to soju
- multi-platform image contains linux/amd64 and linux/arm64
- base images are pinned by multi-platform digest
- GitHub Actions are pinned by commit SHA
- upstream Gamja source is pinned by commit SHA
- SBOM generation is enabled for published images
- BuildKit provenance is enabled with `mode=max`

## Versioning

Releases use semantic version tags:

```text
vMAJOR.MINOR.PATCH
```

The first release is `v0.1.0`.

A `v0.1.0` tag publishes these aliases:

```text
ghcr.io/ploos-as/gamja:0.1.0
ghcr.io/ploos-as/gamja:0.1
ghcr.io/ploos-as/gamja:0
```

`latest` is published only from the default branch and remains the continuously qualified `main` image.

## Release steps

1. Confirm the latest `main` workflow completed successfully.
2. Confirm the worktree/repository state represented by `main` is the intended release state.
3. Create the annotated release tag from that exact `main` commit.
4. Wait for the tag workflow to complete successfully.
5. Record the published OCI index digest in the GitHub release notes.
6. Verify the tagged manifest contains linux/amd64 and linux/arm64.
7. Verify SBOM and provenance attestations are attached to the published image.

Published tags are immutable release artifacts. Fixes after publication require a new semantic version.
