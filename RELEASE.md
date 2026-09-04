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
- QEMU/binfmt is pinned to a named release and only the required arm64 emulator is installed
- BuildKit is pinned to a named release instead of the floating default builder image
- OCI license metadata is explicitly set to `AGPL-3.0-only`
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

## Automated GitHub release

`.github/workflows/release.yml` listens for successful completion of the `container` workflow. It only proceeds for successful semantic-version tag runs. The workflow then:

1. verifies that the triggering ref is a `vMAJOR.MINOR.PATCH` tag
2. verifies the published versioned image exists
3. reads the OCI index digest from GHCR
4. verifies linux/amd64 and linux/arm64 are present
5. creates the matching GitHub Release if it does not already exist

The release workflow is idempotent. Re-running it for an already published GitHub Release performs no replacement of the release artifact.

## Release steps

1. Confirm the latest `main` workflow completed successfully.
2. Confirm the worktree/repository state represented by `main` is the intended release state.
3. Create the annotated release tag from that exact `main` commit.
4. Wait for the tag-triggered `container` workflow to complete successfully.
5. The generic release workflow creates the GitHub Release from the successful tag run and records the published OCI index digest.
6. Verify the GitHub Release, versioned image, linux/amd64 and linux/arm64 manifests, SBOM, and provenance.

Published tags are immutable release artifacts. Fixes after publication require a new semantic version.
