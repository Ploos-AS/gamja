# Post-release audit

M1.20 extends the release trust chain beyond publication. A release that was valid when created must remain auditable later from its public Git tag, GitHub Release metadata, signed evidence assets, and immutable OCI digest.

M1.21 adds a deterministic machine-readable record of each successful full audit. The record is generated only after the complete M1.20/M1.19 verification chain succeeds, is checksummed locally, and is archived as an immutable GitHub Actions artifact.

M1.22 adds the canonical consumer for that archived record. It verifies the exact checksum filename and bytes, enforces the closed audit-record v1 schema, validates release/commit/digest syntax, and requires every recorded verification claim to remain true before the record is trusted or archived.

M1.23 cryptographically authenticates the deterministic audit record itself. `release-verification.yml` keylessly signs the exact `release-audit.json` bytes with Cosign and GitHub Actions OIDC, writes a Sigstore bundle beside the deterministic JSON/checksum pair, and verifies that bundle against the expected workflow identity before archival.

M1.24 makes that signed audit evidence durable beyond GitHub Actions artifact retention. The first successful M1.24 audit publishes the exact signed audit triplet as GitHub Release assets without overwrite. Later audits must reproduce the deterministic JSON/checksum byte-for-byte, verify the originally published M1.23 bundle, and leave those durable assets unchanged. The 90-day Actions artifact remains only a secondary cache.

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

Before M1.24 retention has been established, the audit accepts exactly these three non-empty release assets:

- `release-evidence.json`
- `release-evidence.json.sha256`
- `release-evidence.bundle.json`

After the first successful M1.24 retention pass, the only other accepted state is exactly these six non-empty assets:

- `release-evidence.json`
- `release-evidence.json.sha256`
- `release-evidence.bundle.json`
- `release-audit.json`
- `release-audit.json.sha256`
- `release-audit.bundle.json`

No partial audit set and no unrelated extra asset is accepted. This preserves the exact-asset-set property while allowing one deliberate, policy-defined transition from signed release evidence to signed release evidence plus durable post-release audit evidence.

The audit also requires the peeled Git tag commit to equal `release_evidence.release_commit` and the evidence tag to equal the audited GitHub Release tag.

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

The JSON intentionally contains no wall-clock timestamp, runner name, workflow run ID, or other volatile value. Auditing the same unchanged release twice therefore produces byte-identical JSON and the same SHA-256 checksum. Workflow-run metadata belongs outside the deterministic record.

## M1.22 canonical audit consumer

`scripts/verify-audit-record.sh` is the canonical consumer for the M1.21 record pair. With two arguments it validates deterministic byte integrity and the closed v1 semantic contract:

```sh
./scripts/verify-audit-record.sh release-audit.json release-audit.json.sha256
```

It requires both files to share a directory and their canonical names. The checksum file must contain exactly a lowercase SHA-256 for `release-audit.json`; filename substitution is rejected. The consumer then enforces exact top-level and nested keys, the canonical schema URI, M1.21 producer identity, valid SemVer tag, 40-character lowercase Git commit, exact lowercase sha256 OCI digest, immutable image marker, the exact verifier identities, and the complete known verification-claim set with every value `true`.

This distinction is intentional: M1.21 produces a deterministic audit result, while M1.22 defines how a consumer decides whether that result is structurally trustworthy. A checksum alone is not sufficient because an attacker or accidental process could modify and rechecksum semantically false JSON.

## M1.23 keyless audit-record signature

The first M1.24 retention pass signs the exact M1.21 JSON bytes under the `release-verification.yml` GitHub Actions OIDC identity using:

```sh
cosign sign-blob --yes \
  --bundle release-audit.bundle.json \
  release-audit.json
```

The deterministic JSON and checksum remain unchanged. Signature material lives separately in `release-audit.bundle.json`, so the M1.21 reproducibility property is preserved.

The canonical M1.23 verification form adds the bundle as a third argument:

```sh
./scripts/verify-audit-record.sh \
  release-audit.json \
  release-audit.json.sha256 \
  release-audit.bundle.json
```

The verifier first repeats every M1.22 checksum/schema/claim check, then verifies the Cosign bundle against:

- OIDC issuer: `https://token.actions.githubusercontent.com`
- workflow identity: `https://github.com/Ploos-AS/gamja/.github/workflows/release-verification.yml@refs/heads/main`

Production uses those defaults. `AUDIT_RECORD_IDENTITY` and `AUDIT_RECORD_OIDC_ISSUER` exist only so deterministic policy workflows can verify their own short-lived OIDC identity and exercise negative identity/issuer cases.

A modified record cannot be made trustworthy merely by generating a new SHA-256 file: the M1.23 signature covers the exact JSON bytes. A bundle from another workflow identity or issuer is rejected.

## M1.24 durable retention

`scripts/retain-audit-record.sh` implements the durable state transition. It accepts only:

1. the original M1.20 evidence-only three-asset state; or
2. the completed M1.24 six-asset state.

For the evidence-only state it keylessly signs the current deterministic audit record, verifies that M1.23 bundle locally, and uploads the three audit files with `gh release upload` without `--clobber`. It then re-reads the release and requires the exact six-asset state.

For an already retained release it does not generate or overwrite a new durable signature. Instead it downloads the existing audit triplet, requires the freshly recomputed `release-audit.json` and checksum to be byte-identical to the published pair, and verifies the original bundle with the canonical M1.23 consumer. This makes later weekly/manual audits a reproducibility and authenticity check of the retained evidence rather than a mutation of the release.

After either path succeeds, the workflow copies the verified durable bundle beside the fresh deterministic pair and also uploads that exact triplet as a 90-day Actions artifact. That artifact is intentionally secondary; long-term retention is provided by the GitHub Release assets.

The retention path refuses partial audit assets, unrelated extra assets, empty assets, checksum drift, deterministic JSON drift, an invalid M1.23 signature, or any attempt to rely on overwrite semantics.

## Continuous audit

`.github/workflows/release-verification.yml` runs:

- immediately when a GitHub Release is published;
- manually for an explicitly selected release tag;
- every Monday at 06:17 UTC against the newest release that carries the M1.19 signed evidence bundle.

Legacy releases without `release-evidence.bundle.json` are not labeled M1.20+ compliant. A scheduled run with no eligible release reports that state and exits successfully rather than falsely failing an older release against a contract that did not exist when it was published.

## Deterministic policy qualification

`release-policy` exercises the M1.20/M1.24 metadata envelope with local GitHub/Git fixtures. It verifies that both the original three-asset state and the completed six-asset state are accepted, while partial/unexpected assets and tag/evidence commit mismatches are rejected.

`audit-record-policy` exercises the M1.21 record generator twice with identical inputs and requires byte-identical output. It validates the checksum, rejects malformed OCI digests, verifies archive wiring, and independently fetches the exact pinned `actions/upload-artifact` commit.

`audit-consumer-policy` exercises M1.22 entirely offline. It accepts a canonical fixture and rejects byte tampering, a rechecksummed false verification claim, unknown top-level fields, and checksum filename substitution.

`audit-signature-policy` exercises M1.23 with a real short-lived GitHub Actions OIDC identity. It keylessly signs the exact fixture bytes, verifies the expected workflow identity, rejects the production identity when it did not sign the fixture, rejects a wrong issuer, and rejects tampered/rechecksummed bytes against the original bundle.

`audit-retention-policy` exercises the M1.24 retention state machine with deterministic fake GitHub Release transport and a fake Cosign transport around the real M1.22 schema/checksum consumer. It requires first publication without clobber, exact six-asset post-state, idempotent reuse without upload, byte-for-byte reproduction of the retained record/checksum, and rejection of partial/extra release asset states.

`--metadata-only` is solely for deterministic M1.20/M1.24 envelope policy tests. It does not replace the full cryptographic/OCI audit and cannot produce an M1.21 compliance record.
