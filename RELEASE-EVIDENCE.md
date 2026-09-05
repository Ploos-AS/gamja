# Release evidence

The GitHub Release carries a machine-readable evidence bundle for the exact OCI artifact that passed the release gates:

- `release-evidence.json` — canonical release identity and verification summary;
- `release-evidence.json.sha256` — SHA-256 checksum of that JSON file.

The evidence binds the release tag, version, exact OCI index digest, Git commit, supported platforms, Cosign identity, attestations, and runtime qualification.

## M1.18 runtime binding

M1.18 closes the gap between runtime qualification and the published evidence. Evidence is now generated **after** the exact release digest has executed successfully on both `linux/amd64` and `linux/arm64`.

The recorded runtime contract requires:

- the immutable OCI digest, never a mutable tag;
- both `linux/amd64` and `linux/arm64`;
- runtime UID 101;
- read-only root filesystem;
- `no-new-privileges`;
- healthy container state;
- generated Gamja `/config.json` verification;
- a real `/socket` WebSocket HTTP 101 upgrade to same-platform soju.

`verification.runtime_verified` is therefore emitted only in the release workflow after the two blocking M1.17 runtime executions have passed. The release-policy workflow enforces the ordering `runtime -> evidence -> consumer verification -> GitHub Release`.

## Other enforced evidence

Before publication the release path also verifies:

1. tag -> successful container workflow commit;
2. OCI revision -> same release commit;
3. Cosign keyless signature -> exact OCI digest and tag-scoped `container.yml` identity;
4. SPDX SBOM -> linux/amd64 and linux/arm64;
5. BuildKit SLSA provenance -> linux/amd64 and linux/arm64;
6. exact-digest runtime contract -> linux/amd64 and linux/arm64.

The JSON is a compact record of already-enforced facts, not a substitute for the underlying cryptographic or runtime checks.

## Determinism

`scripts/create-release-evidence.sh` takes release identity through explicit environment variables and emits stable JSON without timestamps or runner-specific data. For identical inputs its output is identical.

## Consumer verification

`scripts/verify-release.sh` validates the checksum and strict evidence policy, including the M1.18 runtime fields. In full mode it additionally verifies OCI revision, exact Cosign identity, SPDX SBOM and BuildKit SLSA provenance against the immutable digest.

```sh
./scripts/verify-release.sh release-evidence.json release-evidence.json.sha256
```

`--metadata-only` exists for deterministic policy testing. It validates checksum and evidence semantics without contacting the registry and is not a substitute for full verification.

`.github/workflows/release-verification.yml` independently downloads the public release assets after publication and repeats the consumer verification path.

The OCI digest remains the artifact identity.
