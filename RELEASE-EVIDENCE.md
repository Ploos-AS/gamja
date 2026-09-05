# Release evidence

The GitHub Release carries a machine-readable evidence bundle for the exact OCI artifact that passed the release gates:

- `release-evidence.json` — canonical release identity and verification summary;
- `release-evidence.json.sha256` — SHA-256 checksum of that JSON file;
- `release-evidence.bundle.json` — Cosign keyless signature bundle for the exact JSON bytes.

The evidence binds the release tag, version, exact OCI index digest, Git commit, supported platforms, image Cosign identity, attestations, runtime qualification, and the expected evidence signer identity.

## M1.18 runtime binding

M1.18 closes the gap between runtime qualification and the published evidence. Evidence is generated **after** the exact release digest has executed successfully on both `linux/amd64` and `linux/arm64`.

The recorded runtime contract requires:

- the immutable OCI digest, never a mutable tag;
- both `linux/amd64` and `linux/arm64`;
- runtime UID 101;
- read-only root filesystem;
- `no-new-privileges`;
- healthy container state;
- generated Gamja `/config.json` verification;
- a real `/socket` WebSocket HTTP 101 upgrade to same-platform soju.

`verification.runtime_verified` is therefore emitted only in the release workflow after the two blocking M1.17 runtime executions have passed.

## M1.19 cryptographic evidence authenticity

A standalone checksum is useful for corruption detection but does not prove who created the file: an attacker who changes the JSON could also publish a matching replacement checksum. M1.19 closes that gap.

After M1.18 evidence generation, `.github/workflows/release.yml` obtains a GitHub Actions OIDC identity and signs the exact `release-evidence.json` bytes with Cosign `sign-blob`. The resulting `release-evidence.bundle.json` is verified before release publication and is published alongside the JSON and checksum.

The expected evidence signer is fixed to:

```text
issuer:   https://token.actions.githubusercontent.com
identity: https://github.com/Ploos-AS/gamja/.github/workflows/release.yml@refs/heads/main
```

The deterministic JSON records that expected signer under `evidence_signature`, while the Sigstore bundle carries the cryptographic proof. Full consumer verification requires both.

The release-policy workflow enforces the ordering:

```text
runtime -> evidence -> evidence signature -> consumer verification -> GitHub Release
```

Unsigned evidence cannot pass the full consumer path.

## Other enforced evidence

Before publication the release path also verifies:

1. tag -> successful container workflow commit;
2. OCI revision -> same release commit;
3. Cosign keyless image signature -> exact OCI digest and tag-scoped `container.yml` identity;
4. SPDX SBOM -> linux/amd64 and linux/arm64;
5. BuildKit SLSA provenance -> linux/amd64 and linux/arm64;
6. exact-digest runtime contract -> linux/amd64 and linux/arm64;
7. Cosign keyless blob signature -> exact runtime-bound release evidence.

The JSON is a compact record of already-enforced facts. The image signature, attestations, runtime execution, and M1.19 evidence signature remain independently verifiable.

## Determinism

`scripts/create-release-evidence.sh` takes release identity through explicit environment variables and emits stable JSON without timestamps or runner-specific data. For identical inputs its output is identical.

The Sigstore bundle is intentionally not deterministic: it contains signing material associated with the live OIDC signing event. It signs the deterministic JSON rather than becoming part of that JSON.

## Consumer verification

`scripts/verify-release.sh` validates the checksum and strict evidence policy, including the M1.18 runtime fields and the expected M1.19 evidence signer. In full mode it first verifies the Cosign blob signature bundle, then verifies OCI revision, the exact image Cosign identity, SPDX SBOM, and BuildKit SLSA provenance against the immutable digest.

```sh
./scripts/verify-release.sh \
  release-evidence.json \
  release-evidence.json.sha256 \
  release-evidence.bundle.json
```

`--metadata-only` exists only for deterministic policy testing. It validates checksum and evidence semantics without validating the Sigstore bundle or contacting the registry and is not a substitute for full verification.

`.github/workflows/release-verification.yml` independently downloads all three public release assets after publication and repeats the full consumer verification path.

The OCI digest remains the container artifact identity; the M1.19 signature authenticates the release evidence that describes how that artifact was qualified.
