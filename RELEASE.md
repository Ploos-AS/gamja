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

A `v0.1.0` tag publishes these aliases:

```text
ghcr.io/ploos-as/gamja:0.1.0
ghcr.io/ploos-as/gamja:0.1
ghcr.io/ploos-as/gamja:0
```

`latest` is published by the container workflow and remains the continuously qualified default image.

## Automated GitHub releases

`.github/workflows/release.yml` listens for successful completion of the `container` workflow. It only proceeds when the triggering ref is a semantic-version tag matching `vMAJOR.MINOR.PATCH` (with optional SemVer pre-release/build suffix).

For an eligible successful tag build, the release workflow:

1. verifies that the Git tag exists;
2. resolves the published OCI index digest directly from GHCR;
3. creates a GitHub Release for the existing immutable tag;
4. records the image reference, OCI digest, release commit, supported architectures, SBOM and provenance status;
5. exits cleanly if that GitHub Release already exists.

This keeps GitHub Releases downstream of the qualified container build instead of racing the registry publication.

## Release steps

1. Confirm the latest `main` workflow completed successfully.
2. Confirm the repository state represented by `main` is the intended release state.
3. Create an annotated semantic-version tag from that exact `main` commit.
4. Push the tag.
5. The `container` workflow builds, qualifies and publishes the tagged multi-architecture image.
6. After the container workflow succeeds, `release.yml` automatically creates the GitHub Release and records the registry digest.
7. Verify the tagged manifest contains linux/amd64 and linux/arm64 and that SBOM/provenance attestations are present.

Published tags are immutable release artifacts. Fixes after publication require a new semantic version.
