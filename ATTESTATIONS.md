# OCI attestations

Published Gamja images include BuildKit-generated attestations attached to the OCI image index.

M1.13 turns those attestations into an enforced release property instead of treating their generation as sufficient.

## Required attestations

For both `linux/amd64` and `linux/arm64`, the exact published OCI digest must expose:

- an SPDX SBOM whose document root is `SPDXRef-DOCUMENT`
- BuildKit SLSA provenance in the current v1-style structure
- `buildDefinition.buildType` equal to `https://github.com/moby/buildkit/blob/master/docs/attestations/slsa-definitions.md`
- structured external parameters and resolved dependencies
- structured run details with builder identity and metadata

The container build publishes SBOM data through the pinned BuildKit Syft scanner and provenance with `mode=max`.

## Verification

The repository provides:

```sh
./scripts/verify-attestations.sh ghcr.io/ploos-as/gamja@sha256:<digest>
```

The verifier uses `docker buildx imagetools inspect` against the immutable digest and validates the decoded SPDX and SLSA structures with `jq` independently for both supported platforms.

Do not use a mutable tag as evidence for a release decision. Resolve and verify the exact OCI digest.

## Continuous qualification

`.github/workflows/attestations.yml` runs after a successful `container` workflow on `main`, can be invoked manually, and repeats daily. It resolves `latest` to its immutable digest and verifies both required attestation types for both platforms.

## Release enforcement

For a version tag, `.github/workflows/release.yml` first establishes the M1.8/M1.12 identity chain and verifies the Cosign signature. It then runs the same attestation verifier against the exact release digest.

A GitHub Release is not created if the SPDX SBOM or BuildKit SLSA provenance is missing or fails structural validation for either supported platform.
