# Release evidence

M1.14 makes each GitHub Release carry a small machine-readable evidence bundle for the exact OCI artifact that passed the release gates. M1.15 adds a single consumer verifier for that bundle and enforces the same verification path before and after release publication.

## Assets

A successful version release attaches:

- `release-evidence.json` — canonical release identity and verification summary;
- `release-evidence.json.sha256` — SHA-256 checksum of that JSON file.

The evidence records the release tag and version, exact OCI image and index digest, exact Git commit, supported platforms, expected Cosign keyless workflow identity, attestation families, and the integrity gates completed before evidence generation.

Evidence is generated only after the release workflow has independently verified:

1. tag -> successful container workflow commit;
2. OCI revision -> same release commit;
3. Cosign keyless signature -> exact OCI digest and tag-scoped `container.yml` identity;
4. SPDX SBOM -> linux/amd64 and linux/arm64;
5. BuildKit SLSA provenance -> linux/amd64 and linux/arm64.

The JSON is therefore a compact record of already-enforced facts, not a substitute for cryptographic signature or attestation verification.

## Determinism

`scripts/create-release-evidence.sh` takes release identity through explicit environment variables and emits stable JSON without timestamps or runner-specific data. For the same tag, version, image, digest and commit, its semantic output is identical.

The release workflow validates the generated JSON, computes its SHA-256 checksum, and uploads both files as GitHub Release assets in the same release-creation operation. The release-policy workflow continuously checks this ordering and wiring.

## M1.15 consumer verification

`scripts/verify-release.sh` is the canonical consumer path. Given the two release assets it verifies:

1. SHA-256 integrity of `release-evidence.json`;
2. strict release-evidence schema and policy fields;
3. exact tag/version/image/digest/commit formats;
4. exact required platform set: linux/amd64 and linux/arm64;
5. OCI index revision equals the recorded release commit;
6. the exact Cosign keyless identity `container.yml@refs/tags/<tag>` and GitHub Actions OIDC issuer;
7. SPDX SBOM and BuildKit SLSA provenance for both supported platforms.

Full verification requires `jq`, `sha256sum`, `cosign`, and Docker with Buildx available.

Example after downloading the two release assets:

```sh
./scripts/verify-release.sh release-evidence.json release-evidence.json.sha256
```

`--metadata-only` is available for deterministic policy testing and validates checksum plus all evidence semantics without contacting the registry. It is not a substitute for the default full verification mode.

## Publication enforcement

The release workflow runs the full consumer verifier against the newly generated evidence before `gh release create`. A release therefore cannot be published unless the same path documented for consumers accepts the artifact.

`.github/workflows/release-verification.yml` then runs independently when a GitHub Release is published. It downloads the public release assets, checks out the exact release tag, installs the pinned Cosign version, and repeats full consumer verification against the published files and immutable OCI digest. It can also be invoked manually for an existing release tag.

The digest, not a mutable container tag, remains the artifact identity.
