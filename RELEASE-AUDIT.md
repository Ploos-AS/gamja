# Post-release audit

M1.20 extends the release trust chain beyond publication. A release that was valid when created must remain auditable later from its public Git tag, GitHub Release metadata, signed evidence assets, and immutable OCI digest.

## Audit command

For an M1.20-compatible release:

```sh
./scripts/audit-release.sh v0.2.0
```

The full audit requires `gh`, `git`, `jq`, `cosign`, Docker with Buildx, and network access to GitHub, GHCR and Sigstore verification services.

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

## Continuous audit

`.github/workflows/release-verification.yml` runs:

- immediately when a GitHub Release is published;
- manually for an explicitly selected release tag;
- every Monday at 06:17 UTC against the newest release that carries the M1.19 signed evidence bundle.

Legacy releases without `release-evidence.bundle.json` are not labeled M1.20-compliant. A scheduled run with no eligible release reports that state and exits successfully rather than falsely failing an older release against a contract that did not exist when it was published.

## Deterministic policy qualification

`release-policy` exercises the metadata-only audit path with local GitHub/Git fixtures. It verifies that a correct release envelope is accepted and that both an unexpected extra asset and a tag/evidence commit mismatch are rejected.

`--metadata-only` is solely for deterministic policy tests. It does not replace the full cryptographic/OCI audit.
