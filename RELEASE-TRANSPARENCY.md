# Release transparency index

M1.25 adds a deterministic, machine-readable index over releases that have completed the M1.20-M1.24 evidence and durable-audit contract.

The index is deliberately a **reconstructable view**, not a new mutable source of truth. The permanent GitHub Release assets remain authoritative. Any consumer with access to those assets can rebuild the same index and verify its byte bindings.

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

## Continuous qualification

`.github/workflows/release-transparency.yml` runs on `main`, pull requests, manual dispatch and daily schedule. It also runs after successful `release-verification`, so a newly durable M1.24 audit becomes visible in the transparency view immediately after the post-release audit completes.

The workflow tests deterministic fixtures and negative cases for:

- canonical ordering
- six asset hashes per release
- modified index claims
- modified release-asset bytes
- partial M1.24 asset states
- the valid empty-history case

It then reconstructs the index from the repository's live GitHub Releases and verifies the result. A 90-day Actions artifact containing `release-index.json` and its checksum is retained as a convenient snapshot; that artifact is not authoritative and is not required to reconstruct the index.

## Trust model

M1.25 does not replace M1.19 evidence signatures or M1.23 audit signatures. It points at and SHA-256-binds the durable objects whose cryptographic verification is handled by the existing release/audit consumer paths.

This separation avoids a circular transparency design: release assets are immutable evidence, while the index is a deterministic discovery and integrity view over release history. If the view disappears, it can be recreated; if an indexed asset changes, the recorded SHA-256 binding changes and verification fails against an older snapshot.
