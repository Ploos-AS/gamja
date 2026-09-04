# Release runtime qualification

M1.16 adds an execution gate for the exact immutable OCI digest that is about to become a GitHub Release.

Supply-chain verification proves what an artifact is and where it came from. M1.16 additionally proves that the same digest still satisfies the runtime contract expected by operators.

## Canonical qualifier

`scripts/qualify-release-runtime.sh` accepts exactly one digest-bound image reference:

```sh
./scripts/qualify-release-runtime.sh \
  ghcr.io/ploos-as/gamja@sha256:<digest>
```

Mutable tags such as `latest` are rejected by the script.

The qualifier:

- pulls the exact OCI index digest for linux/amd64
- starts the exact Gamja artifact as UID 101
- requires a read-only root filesystem
- requires `no-new-privileges`
- provides only `/tmp` as transient writable state
- waits for the image health check to become healthy
- verifies the Gamja index and runtime-generated `/config.json`
- checks the default `/socket` server URL
- starts the immutably pinned Ploos-AS soju image on an isolated Docker network
- performs a real RFC 6455 WebSocket handshake through Gamja/nginx to soju
- requires HTTP 101 plus the expected Upgrade/Connection response headers

The soju qualification dependency is pinned to:

```text
ghcr.io/ploos-as/soju:latest@sha256:ae1eb58d75beea7bfbeff3f004700289f2fcd4c56da671d88216f2cfb2d1d491
```

## Continuous qualification

`.github/workflows/release-runtime.yml` runs after a successful `container` workflow on `main`.

It does not trust `latest` by name alone. It waits for GHCR consistency, reads the OCI index annotation, requires `org.opencontainers.image.revision` to equal the exact successful container workflow commit, resolves that index digest, and passes only the resulting digest-bound reference to the runtime qualifier.

This makes the M1.16 script itself continuously exercised without creating a release tag.

## Release blocking

For a real version tag, `.github/workflows/release.yml` already resolves and validates the exact versioned OCI digest. After signature, attestation, release-evidence and consumer verification succeed, M1.16 runs the exact same digest through `qualify-release-runtime.sh`.

`gh release create` is ordered after this step. A release therefore cannot be created if the exact published digest fails its runtime identity, health, generated configuration, or WebSocket proxy contract.

## Scope

M1.16 currently executes linux/amd64 because GitHub's release runner is amd64. The OCI index is still separately required to contain linux/amd64 and linux/arm64, and M1.13 verifies SBOM/provenance for both platforms.

Architecture-native arm64 runtime execution would require an arm64 runner or an explicit emulated runtime qualification policy and is not silently claimed here.
