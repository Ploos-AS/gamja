# M1.27 live transparency consumer

M1.27 adds an independent consumer path for the signed M1.26 release-transparency snapshot.

M1.26 proves that a deterministic `release-index.json` snapshot is internally valid and was signed by the expected `release-transparency.yml@refs/heads/main` GitHub Actions OIDC identity. M1.27 additionally proves that the signed snapshot still represents the current authoritative GitHub Release asset state.

## Canonical verification

Download these three files from a successful `release-transparency` Actions artifact:

- `release-index.json`
- `release-index.json.sha256`
- `release-index.bundle.json`

Then run:

```sh
GH_TOKEN=... ./scripts/verify-live-transparency.sh \
  release-index.json \
  release-index.json.sha256 \
  release-index.bundle.json
```

The verifier first delegates to the M1.26 canonical snapshot verifier. That checks canonical filenames, checksum syntax and bytes, the closed M1.25 index contract, and the Cosign/Sigstore bundle against:

```text
https://github.com/Ploos-AS/gamja/.github/workflows/release-transparency.yml@refs/heads/main
```

with issuer:

```text
https://token.actions.githubusercontent.com
```

It then independently calls `collect-release-index.sh` against current GitHub Releases, validates the newly reconstructed index, and requires the reconstructed JSON to be byte-identical to the signed snapshot.

A mismatch fails closed and reports both SHA-256 values. This can indicate that release transparency state changed after the snapshot, that an indexed durable asset changed, or that the supplied snapshot does not describe the current live release state.

## Workflow separation

`.github/workflows/transparency-live-consumer.yml` is separate from the producer workflow. After a successful `release-transparency` run it downloads the producer's archived M1.26 artifact, verifies its signature, independently reconstructs current live release history, and requires byte equality.

The consumer also runs on a daily schedule and manual dispatch. Scheduled/manual runs use the newest successful `release-transparency` run on `main` as the signed observation to compare against current releases.

Pull requests qualify shell syntax and fail-closed argument handling but deliberately do not consume a production signed artifact from unmerged PR code.

## Trust model

M1.27 does not add a new signed object and does not make Actions artifacts authoritative. GitHub Release evidence/audit assets remain the durable source of truth. The signed M1.26 snapshot remains a reconstructable historical observation. M1.27 simply verifies that one authenticated observation is exactly reproducible from the current authoritative release state.

This intentionally creates a useful freshness property: an older valid signed snapshot can remain cryptographically authentic while failing M1.27 if the release history has legitimately advanced. In that case a newer successful `release-transparency` snapshot is required for current-live equivalence.
