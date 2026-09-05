# Release transparency index

M1.25 adds a deterministic, machine-readable index over releases that have completed the M1.20-M1.24 evidence and durable-audit contract.

M1.26 keylessly signs each reconstructed transparency snapshot with GitHub Actions OIDC. The signature authenticates the exact deterministic `release-index.json` bytes while preserving the M1.25 trust model: the snapshot is still a reconstructable view, not a new mutable source of truth.

The permanent GitHub Release assets remain authoritative. Any consumer with access to those assets can rebuild the same index, verify its byte bindings, and independently verify the M1.26 snapshot signature.

## Indexed release contract

An indexed release must expose exactly the six durable evidence/audit assets established by M1.24:

- `release-evidence.json`
- `release-evidence.json.sha256`
- `release-evidence.bundle.json`
- `release-audit.json`
- `release-audit.json.sha256`
- `release-audit.bundle.json`

A release with no M1.20 evidence is outside the M1.25 index. If any M1.20-M1.24 transparency asset is present, the complete six-asset state is required; partial or unexpected transparency states fail collection.

## Index schema

The generated JSON uses:

```text
https://github.com/Ploos-AS/gamja/releases/transparency-index/v1
```

and records `milestone: M1.25` plus deterministic `bytewise-tag-ascending` ordering.

Each release entry binds:

- release tag
- exact 40-character Git release commit
- image repository
- immutable OCI `sha256:` digest
- SHA-256 of each of the six durable evidence/audit release assets

The evidence and audit records must agree on tag, release commit, image name and immutable image digest before an entry can be generated.

## Rebuild the index

For live GitHub releases:

```sh
GH_TOKEN=... ./scripts/collect-release-index.sh release-index.json
```

The collector paginates through non-draft GitHub Releases, ignores releases with no M1.20 transparency material, downloads each complete six-asset set, verifies both published checksum files, verifies evidence/audit cross-binding, and then builds the canonical index.

For an already downloaded asset tree where each subdirectory is named by tag:

```text
releases/
  v1.0.0/
    release-evidence.json
    release-evidence.json.sha256
    release-evidence.bundle.json
    release-audit.json
    release-audit.json.sha256
    release-audit.bundle.json
```

build and verify with:

```sh
./scripts/create-release-index.sh releases release-index.json
./scripts/verify-release-index.sh release-index.json releases
```

`verify-release-index.sh` without the asset-root argument verifies the closed index schema, canonical ordering, unique tags, identity formats and all recorded asset hashes. With the root argument it additionally checks every indexed asset byte-for-byte and rechecks evidence/audit tag/commit/image/digest binding.

## M1.26 signed snapshot contract

On `refs/heads/main`, `.github/workflows/release-transparency.yml` creates three snapshot files:

- `release-index.json`
- `release-index.json.sha256`
- `release-index.bundle.json`

The checksum file uses the canonical basename `release-index.json`. The exact JSON bytes are then signed with Cosign keyless signing and the short-lived GitHub Actions OIDC identity of:

```text
https://github.com/Ploos-AS/gamja/.github/workflows/release-transparency.yml@refs/heads/main
```

The expected OIDC issuer is:

```text
https://token.actions.githubusercontent.com
```

No long-lived signing key is stored.

Verify a downloaded snapshot with:

```sh
./scripts/verify-transparency-snapshot.sh \
  release-index.json \
  release-index.json.sha256 \
  release-index.bundle.json
```

If the six release assets are also available locally under a tag-named asset tree, pass that tree as the fourth argument to add byte-for-byte M1.25 asset verification:

```sh
./scripts/verify-transparency-snapshot.sh \
  release-index.json \
  release-index.json.sha256 \
  release-index.bundle.json \
  releases/
```

The verifier requires canonical filenames and checksum syntax, validates the complete M1.25 index contract, and then verifies the Sigstore/Cosign bundle against the expected workflow identity and issuer. Rechecksumming modified JSON does not make it valid because the original signature still covers the prior bytes.

Pull-request runs qualify deterministic index behavior and M1.26 wiring but do not issue production snapshot signatures. Production signing is restricted to `refs/heads/main`.

## Continuous qualification

`.github/workflows/release-transparency.yml` runs on `main`, pull requests, manual dispatch and daily schedule. It also runs after successful `release-verification`, so a newly durable M1.24 audit becomes visible in the transparency view immediately after the post-release audit completes.

The workflow tests deterministic fixtures and negative cases for:

- canonical ordering
- six asset hashes per release
- modified index claims
- modified release-asset bytes
- partial M1.24 asset states
- the valid empty-history case

On `main`, it then reconstructs the index from live GitHub Releases, creates the canonical checksum, keylessly signs the exact JSON bytes, verifies the resulting M1.26 bundle, and archives all three files as a 90-day Actions artifact. The artifact is a convenient signed snapshot; it is not authoritative and is not required to reconstruct the index.

`.github/workflows/transparency-signature-policy.yml` performs a real GitHub OIDC signing qualification. It verifies the expected policy identity and issuer, rejects a wrong workflow identity, rejects a wrong issuer, and rejects modified/rechecksummed JSON against the original bundle.

## Trust model

M1.25 does not replace M1.19 evidence signatures or M1.23 audit signatures. It points at and SHA-256-binds the durable objects whose cryptographic verification is handled by the existing release/audit consumer paths.

M1.26 authenticates one reconstructed view of that history. It still does not promote the snapshot to source of truth: a consumer can discard the snapshot, reconstruct `release-index.json` from durable release assets, and compare the resulting deterministic bytes or SHA-256 with a previously signed snapshot.

This separation avoids a circular transparency design: durable release assets remain immutable evidence, while signed index snapshots provide authenticated discovery and historical observation. If a snapshot disappears, it can be recreated; if an indexed asset changes, reconstruction and older signed snapshots diverge visibly.
