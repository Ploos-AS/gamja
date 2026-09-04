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
- multi-platform image contains linux/amd64 and linux/arm64
- base images and build/security tooling are immutably pinned and continuously qualified
- upstream Gamja source is pinned by commit SHA
- OCI license metadata is `AGPL-3.0-only`
- OCI revision metadata is bound to the exact Git commit built by the workflow
- SBOM generation and BuildKit provenance `mode=max` are enabled
- the published OCI digest is keylessly signed by the repository's `container` workflow using GitHub Actions OIDC

M1.7 security policy is documented in `SECURITY.md`, M1.10 dependency policy in `DEPENDENCIES.md`, and M1.11 signing trust in `SIGNING.md`.

M1.8 binds the release tag, successful container workflow commit, and OCI revision to the same Git commit. M1.12 extends that chain: the exact OCI digest selected for release must also carry a valid Cosign keyless signature from `Ploos-AS/gamja/.github/workflows/container.yml` running on a version tag. GitHub Release creation is downstream of this verification and cannot proceed when signature verification fails.

## Versioning

Release refs use an OCI-compatible subset of Semantic Versioning:

```text
vMAJOR.MINOR.PATCH
vMAJOR.MINOR.PATCH-PRERELEASE
```

Examples: `v0.2.0` and `v0.2.0-rc.1`. Numeric identifiers may not contain leading zeroes. SemVer build metadata (`+build...`) is rejected because `+` cannot map losslessly to an OCI tag.

Stable releases publish full version plus major/minor aliases. `latest` is published only from the default branch and remains the continuously qualified `main` image.

## Automated GitHub release

`.github/workflows/release.yml` listens for successful completion of `container`. For a release tag it:

1. validates the OCI-compatible SemVer tag
2. peels annotated or lightweight tag to its commit
3. requires tag commit == successful container workflow commit
4. verifies the versioned OCI image exists
5. reads the exact OCI index digest
6. verifies linux/amd64 and linux/arm64
7. requires OCI revision == release commit
8. installs the SHA-pinned Cosign verifier
9. verifies the exact digest against GitHub Actions OIDC and the tag-scoped `container.yml` workflow identity
10. creates the matching GitHub Release only after every integrity/signature gate succeeds

The workflow is idempotent: an existing GitHub Release is not replaced.

`.github/workflows/release-policy.yml` continuously qualifies the strict tag validator, M1.8 revision wiring, M1.12 Cosign identity constraints, and ordering of signature verification before release creation.

## Release steps

1. Confirm all `main` qualification workflows are green.
2. Confirm `main` is the intended release state.
3. Create the annotated version tag from that exact commit.
4. Wait for the tag-triggered `container` workflow to build, scan, publish, sign and self-verify the exact digest.
5. The release workflow independently verifies tag -> workflow commit -> OCI revision -> signed digest identity.
6. Only then is the GitHub Release created.
7. Verify the GitHub Release, versioned image, platforms, OCI revision, signature, SBOM and provenance.

Published tags are immutable release artifacts. Fixes require a new semantic version.
