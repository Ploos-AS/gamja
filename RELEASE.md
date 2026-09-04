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
- the published OCI digest is keylessly signed by the repository's `container` workflow using GitHub Actions OIDC
- SPDX SBOM and BuildKit SLSA provenance are present and structurally valid for linux/amd64 and linux/arm64
- deterministic release evidence binds the tag, release commit and exact verified OCI digest
- the exact release digest passes M1.16 runtime qualification as UID 101 with read-only rootfs, healthy state, generated config and a real WebSocket upgrade to pinned soju

M1.7 security policy is documented in `SECURITY.md`, M1.10 dependency policy in `DEPENDENCIES.md`, M1.11 signing trust in `SIGNING.md`, M1.13 attestation policy in `ATTESTATIONS.md`, M1.14/M1.15 evidence and consumer verification in `RELEASE-EVIDENCE.md`, and M1.16 exact-digest runtime qualification in `RELEASE-RUNTIME.md`.

M1.8 binds the release tag, successful container workflow commit, and OCI revision to the same Git commit. M1.12 extends that chain to the exact Cosign-signed OCI digest. M1.13 further requires that the same digest expose valid SPDX SBOM and BuildKit SLSA provenance attestations for both supported platforms before GitHub Release creation. M1.14 records those already-verified facts in deterministic machine-readable release assets. M1.15 verifies the same release identity through the consumer path. M1.16 finally executes the exact release digest and requires the production runtime contract to hold before publication.

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
10. verifies SPDX SBOM and BuildKit SLSA provenance on the exact digest for amd64 and arm64
11. generates and validates deterministic `release-evidence.json` plus its SHA-256 checksum
12. runs the M1.15 consumer verifier against that exact evidence and OCI artifact
13. executes the exact digest through the M1.16 non-root/read-only health/config/WebSocket runtime gate
14. creates the matching GitHub Release with both evidence files attached only after every integrity, signature, attestation, consumer and runtime gate succeeds

The workflow is idempotent: an existing GitHub Release is not replaced.

`.github/workflows/release-policy.yml` continuously qualifies the strict tag validator, M1.8 revision wiring, M1.12 Cosign identity constraints, M1.13 attestation wiring, M1.14 deterministic evidence generation, M1.15 consumer verification and M1.16 runtime-gate ordering before release creation.

`.github/workflows/release-runtime.yml` continuously exercises the M1.16 runtime qualifier against the exact newly published `main` digest. It waits for GHCR consistency and binds `latest` back to the successful container workflow commit through the OCI revision annotation before resolving the immutable digest.

## Release steps

1. Confirm all `main` qualification workflows are green, including `attestations`, `release-runtime` and `release-policy`.
2. Confirm `main` is the intended release state.
3. Create the annotated version tag from that exact commit.
4. Wait for the tag-triggered `container` workflow to build, scan, publish, sign and self-verify the exact digest.
5. The release workflow independently verifies tag -> workflow commit -> OCI revision -> signed digest -> SBOM/provenance attestations.
6. It generates deterministic release evidence and validates the consumer verification path.
7. The exact immutable digest is then executed through the M1.16 release runtime qualifier.
8. Only then is the GitHub Release created with `release-evidence.json` and `release-evidence.json.sha256` attached.
9. Verify the GitHub Release, evidence checksum, versioned image, platforms, OCI revision, signature, SPDX SBOM, BuildKit provenance and release-runtime qualification.

Published tags are immutable release artifacts. Fixes require a new semantic version.
