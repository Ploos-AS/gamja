# Release runtime qualification

M1.16 added an execution gate for the exact immutable OCI digest that is about to become a GitHub Release. M1.17 extends that gate to every supported runtime architecture: linux/amd64 and linux/arm64.

Supply-chain verification proves what an artifact is and where it came from. The release-runtime gate additionally proves that the same digest satisfies the runtime contract expected by operators on both published platforms.

## Canonical qualifier

`scripts/qualify-release-runtime.sh` accepts a digest-bound image reference plus an optional platform:

```sh
./scripts/qualify-release-runtime.sh \
  ghcr.io/ploos-as/gamja@sha256:<digest> linux/amd64

./scripts/qualify-release-runtime.sh \
  ghcr.io/ploos-as/gamja@sha256:<digest> linux/arm64
```

The default platform remains `linux/amd64` for local compatibility. Mutable tags such as `latest` and unsupported platforms are rejected.

For the selected platform the qualifier:

- pulls the exact OCI index digest and selects the requested platform manifest
- starts the exact Gamja artifact as UID 101
- requires a read-only root filesystem
- requires `no-new-privileges`
- provides only `/tmp` as transient writable state
- waits for the image health check to become healthy
- verifies the Gamja index and runtime-generated `/config.json`
- checks the default `/socket` server URL
- starts the same-platform immutably pinned Ploos-AS soju image on an isolated Docker network
- performs a real RFC 6455 WebSocket handshake through Gamja/nginx to soju
- requires HTTP 101 plus the expected Upgrade/Connection response headers

The soju qualification dependency is pinned to:

```text
ghcr.io/ploos-as/soju:latest@sha256:ae1eb58d75beea7bfbeff3f004700289f2fcd4c56da671d88216f2cfb2d1d491
```

## arm64 execution policy

GitHub-hosted release runners are amd64. M1.17 therefore registers arm64 binfmt support with a SHA-pinned `docker/setup-qemu-action` and an immutable `tonistiigi/binfmt` image before executing the arm64 containers.

Current pins:

```text
docker/setup-qemu-action@1f40c72289eff860ee54a304f1438e3cff362e0a
docker.io/tonistiigi/binfmt:qemu-v10.2.3@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0
```

This is explicit emulated runtime qualification, not a claim of native arm64 hardware execution. It executes the real linux/arm64 Gamja and soju manifests under the kernel's registered binfmt/QEMU path.

## Continuous qualification

`.github/workflows/release-runtime.yml` runs after a successful `container` workflow on `main`.

It does not trust `latest` by name alone. It waits for GHCR consistency, requires `org.opencontainers.image.revision` to equal the exact successful container workflow commit, resolves that OCI index digest, then executes that same digest once as linux/amd64 and once as linux/arm64.

This continuously exercises both M1.16's immutable runtime contract and M1.17's cross-architecture contract without creating a release tag.

## Release blocking

For a real version tag, `.github/workflows/release.yml` resolves and validates the exact versioned OCI digest. After signature, attestation, release-evidence and consumer verification succeed, it installs the same pinned QEMU/binfmt tooling and runs the exact digest through the qualifier for linux/amd64 and linux/arm64.

`gh release create` is ordered after both executions. A release therefore cannot be created if either published architecture fails runtime identity, health, generated configuration, or WebSocket proxy qualification.
