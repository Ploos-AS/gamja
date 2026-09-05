# Post-release audit

M1.20 extends the release trust chain beyond publication. A release that was valid when created must remain auditable later from its public Git tag, GitHub Release metadata, signed evidence assets, and immutable OCI digest.

M1.21 adds a deterministic machine-readable record of each successful full audit. The record is generated only after the complete M1.20/M1.19 verification chain succeeds, is checksummed locally, and is archived as an immutable GitHub Actions artifact.

M1.22 adds the canonical consumer for that archived record. It verifies the exact checksum filename and bytes, enforces the closed audit-record v1 schema, validates release/commit/digest syntax, and requires every recorded verification claim to remain true before the record is trusted or archived.

## Audit command

For an M1.20-compatible release:

```sh
./scripts/audit-release.sh v0.2.0
```

The full audit requires `gh`, `git`, `jq`, `cosign`, Docker with Buildx, and network access to GitHub, GHCR and Sigstore verification services.

Set `AUDIT_RECORD_OUT` to emit an M1.21 audit record after a successful full audit:

```sh
AUDIT_RECORD_OUT=release-audit.json ./scripts/audit-release.sh v0.2.0
sha256sum release-audit.json > release-audit.json.sha256
./scripts/verify-audit-record.sh release-audit.json release-audit.json.sha256
```

No audit record is emitted by `--metadata-only`, because that mode does not perform the complete cryptographic/OCI audit.

## Enforced release object

The audit requires:

1. a valid OCI-compatible SemVer release tag;
2. an existing non-draft GitHub Release with the same tag;
3. exactly these three uploaded release assets, all non-empty:
   - `release-evidence.json`
   - `release-evidence.json.sha256`
   - `release-evidence.bundle.json`
4. the peeled Git tag commit to equal `release_evidence.release_commit`;
5. the evidence tag to equal the audited GitHub Release tag.

The exact asset-set rule deliberately makes release mutations visible. Adding, removing or replacing the expected evidence asset set requires a deliberate policy change rather than silently widening what counts as a valid release.

## Cryptographic and OCI checks

After the GitHub Release object and tag binding pass, `scripts/audit-release.sh` invokes the canonical `scripts/verify-release.sh` path. That verifies:

- SHA-256 integrity of the evidence JSON;
- M1.19 Cosign keyless signature over the exact evidence bytes;
- release-workflow OIDC identity;
- exact OCI index digest and revision-to-commit binding;
- Cosign keyless signature for the OCI image;
- linux/amd64 and linux/arm64 presence;
- SPDX SBOM and BuildKit SLSA provenance for both platforms;
- the recorded M1.18/M1.17 runtime-qualified state.

The immutable OCI digest remains the container artifact identity. M1.20 adds an independently repeatable audit of the published GitHub Release envelope around that artifact.

## M1.21 audit record

`scripts/create-audit-record.sh` emits deterministic JSON containing:

- schema and milestone identity;
- audited release tag and peeled commit;
- image name and exact immutable OCI digest;
- explicit boolean results for the GitHub Release envelope, evidence checksum, evidence keyless signature, OCI revision binding, image signature, amd64/arm64 SBOM, amd64/arm64 provenance, and amd64/arm64 runtime qualification;
- the canonical verifier script identities.

The JSON intentionally contains no wall-clock timestamp, runner name, workflow run ID, or other volatile value. Auditing the same unchanged release twice therefore produces byte-identical JSON and the same SHA-256 checksum. The GitHub Actions artifact itself carries the workflow-run identity and immutable artifact digest.

## M1.22 canonical audit consumer

`scripts/verify-audit-record.sh` is the canonical offline consumer for the M1.21 record pair. It accepts exactly:

```sh
./scripts/verify-audit-record.sh release-audit.json release-audit.json.sha256
```

It requires both files to share a directory and their canonical names. The checksum file must contain exactly a lowercase SHA-256 for `release-audit.json`; filename substitution is rejected. The consumer then enforces the closed audit-record v1 contract: exact top-level and nested keys, the canonical schema URI, M1.21 producer identity, valid SemVer tag, 40-character lowercase Git commit, exact lowercase sha256 OCI digest, immutable image marker, the exact verifier identities, and the complete known verification-claim set with every value `true`.

This distinction is intentional: M1.21 produces a deterministic audit result, while M1.22 defines how a consumer decides whether that result is structurally trustworthy. A checksum alone is not sufficient because an attacker or accidental process could modify and rechecksum semantically false JSON.

`.github/workflows/release-verification.yml` now runs the canonical M1.22 consumer after generating the checksum and before `actions/upload-artifact`. A record that fails byte integrity or schema/claim validation is therefore never archived as a successful audit artifact.

The audit record remains evidence that the complete verifier succeeded at audit time. It does not replace the signed release evidence or the immutable OCI digest, and consumers can always rerun the canonical online audit independently.

## Continuous audit

`.github/workflows/release-verification.yml` runs:

- immediately when a GitHub Release is published;
- manually for an explicitly selected release tag;
- every Monday at 06:17 UTC against the newest release that carries the M1.19 signed evidence bundle.

Legacy releases without `release-evidence.bundle.json` are not labeled M1.20+ compliant. A scheduled run with no eligible release reports that state and exits successfully rather than falsely failing an older release against a contract that did not exist when it was published.

## Deterministic policy qualification

`release-policy` exercises the M1.20 metadata-only audit path with local GitHub/Git fixtures. It verifies that a correct release envelope is accepted and that both an unexpected extra asset and a tag/evidence commit mismatch are rejected.

`audit-record-policy` exercises the M1.21 record generator twice with identical inputs and requires byte-identical output. It validates the checksum, rejects malformed OCI digests, verifies archive wiring, and independently fetches the exact pinned `actions/upload-artifact` commit.

`audit-consumer-policy` exercises M1.22 entirely offline. It accepts a canonical fixture and rejects byte tampering, a rechecksummed false verification claim, unknown top-level fields, and checksum filename substitution. It also verifies that the production audit workflow invokes the same consumer before archival.

`--metadata-only` is solely for deterministic M1.20 policy tests. It does not replace the full cryptographic/OCI audit and cannot produce an M1.21 compliance record.
