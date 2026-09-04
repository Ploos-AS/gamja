# Release procedure

This repository publishes `ghcr.io/ploos-as/gamja` from GitHub Actions.

## Release gate

A release candidate must satisfy all of the following on `main`:

- runtime smoke test passes on linux/amd64
- container runs non-root with a read-only root filesystem
- health check reaches `healthy`
- Gamja `/socket` performs a real WebSocket upgrade through nginx to soju
- final runtime image has no fixable `HIGH` or `CRITICAL` OS/library vulnerabilities according to the pinned Trivy qualification
- repository files have no `HIGH` or `CRITICAL` Trivy secret or misconfiguration findings
- security qualification runs before GHCR authentication and image publication
- multi-platform image contains linux/amd64 and linux/arm64
- base images are pinned by multi-platform digest
- GitHub Actions are pinned by commit SHA
- upstream Gamja source is pinned by commit SHA
- QEMU/binfmt is pinned to a named release and only the required arm64 emulator is installed
- BuildKit is pinned to a named release instead of the floating default builder image
- Trivy is pinned to an explicit engine version and the Trivy GitHub Action is pinned by immutable commit SHA
- OCI license metadata is explicitly set to `AGPL-3.0-only`
- OCI revision metadata is bound to the exact Git commit built by the workflow
- SBOM generation is enabled for published images
- BuildKit provenance is enabled with `mode=max`

The M1.7 security policy is documented in `SECURITY.md`. The dedicated `security` workflow also re-runs the security qualification daily so newly disclosed vulnerabilities can be detected even without a source-code change.

M1.8 adds release-integrity qualification. The release tag, successful container workflow commit, and published OCI `org.opencontainers.image.revision` must all identify the same Git commit before a GitHub Release can be created.

## Versioning

Release refs use an OCI-compatible subset of Semantic Versioning:

```text
vMAJOR.MINOR.PATCH
vMAJOR.MINOR.PATCH-PRERELEASE
```

Examples: `v0.2.0` and `v0.2.0-rc.1`.

Numeric major/minor/patch and numeric prerelease identifiers may not contain leading zeroes. SemVer build metadata (`+build...`) is deliberately rejected because `+` is not valid in an OCI/Docker tag and therefore cannot map losslessly to the published image name.

The first release is `v0.1.0`.

A stable `v0.1.0` tag publishes these aliases:

```text
ghcr.io/ploos-as/gamja:0.1.0
ghcr.io/ploos-as/gamja:0.1
ghcr.io/ploos-as/gamja:0
```

`latest` is published only from the default branch and remains the continuously qualified `main` image.

## Automated GitHub release

`.github/workflows/release.yml` listens for successful completion of the `container` workflow. It only proceeds for successful, strictly validated release-tag runs. The workflow then:

1. validates the release tag with `scripts/validate-release-tag.sh`
2. peels either an annotated or lightweight Git tag to its commit
3. requires that tag commit to equal the successful `container` workflow commit
4. verifies the published versioned image exists
5. reads the OCI index digest from GHCR
6. verifies linux/amd64 and linux/arm64 are present
7. requires the OCI index `org.opencontainers.image.revision` annotation to equal the same release commit
8. creates the matching GitHub Release if it does not already exist

The release workflow is idempotent. Re-running it for an already published GitHub Release performs no replacement of the release artifact.

`.github/workflows/release-policy.yml` continuously qualifies the strict tag validator and verifies that the release and container workflows retain the M1.8 integrity wiring.

## Release steps

1. Confirm the latest `main` container, security, and release-policy workflows completed successfully.
2. Confirm the repository state represented by `main` is the intended release state.
3. Create the annotated release tag from that exact `main` commit.
4. Wait for the tag-triggered `container` workflow to complete successfully, including the release-blocking M1.7 security scans and OCI revision verification.
5. The generic release workflow verifies tag -> workflow commit -> OCI revision identity before creating the GitHub Release.
6. Verify the GitHub Release, versioned image, linux/amd64 and linux/arm64 manifests, OCI revision, SBOM, provenance, and security qualification.

Published tags are immutable release artifacts. Fixes after publication require a new semantic version.