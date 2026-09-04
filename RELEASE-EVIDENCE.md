# Release evidence

M1.14 makes each GitHub Release carry a small machine-readable evidence bundle for the exact OCI artifact that passed the release gates.

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

## Consumer verification

A consumer can first verify `release-evidence.json.sha256`, then use the recorded immutable OCI digest for independent Cosign and BuildKit attestation verification. The digest, not a mutable container tag, is the artifact identity.
