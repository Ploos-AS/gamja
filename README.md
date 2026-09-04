# Gamja container

A small, reproducible, multi-architecture OCI image for [Gamja](https://github.com/Libera-Chat/gamja), the IRC web client commonly paired with [soju](https://soju.im/).

This repository packages upstream Gamja; it is not the upstream Gamja project.

## Image

```text
ghcr.io/ploos-as/gamja:latest
```

Targets:

- linux/amd64
- linux/arm64
- non-root runtime
- read-only-root-filesystem friendly
- no Node.js in the runtime image
- reproducible upstream source pin
- pinned multi-platform base-image digests
- pinned GitHub Actions by commit SHA
- pinned QEMU/binfmt and BuildKit
- explicit OCI license metadata
- SBOM and BuildKit provenance on published images
- runtime Gamja configuration through environment variables

The current build is pinned to upstream commit:

```text
0f273b96994fb32b3a1b868d4b59229285f3455c
```

## Architecture

```text
Browser -> Gamja/nginx :8080 -> /socket -> soju WebSocket -> IRC networks
```

The container generates `/config.json` at startup under `/tmp` and serves it through nginx. No image rebuild is required for normal Gamja server configuration.

## Quick start

If a soju container named `soju` is reachable on the same container network and listens for HTTP/WebSocket traffic on port 8080:

```sh
docker compose up -d
```

Then open `http://localhost:8080`.

Example override:

```sh
GAMJA_NICK='guest*' GAMJA_AUTOJOIN='#gamja' GAMJA_AUTOCONNECT=true docker compose up -d
```

## Runtime configuration

Proxy variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SOJU_HOST` | `soju` | DNS name or address of the soju service |
| `SOJU_PORT` | `8080` | soju HTTP/WebSocket listener port |

Gamja variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `GAMJA_SERVER_URL` | `/socket` | WebSocket URL or path |
| `GAMJA_AUTH` | `optional` | `mandatory`, `optional`, `disabled`, `external`, or `oauth2` |
| `GAMJA_AUTOJOIN` | unset | Channel to join automatically |
| `GAMJA_NICK` | unset | Default nickname; `*` retains upstream random-suffix behavior |
| `GAMJA_AUTOCONNECT` | unset | `true` or `false` |
| `GAMJA_PING` | unset | Non-negative PING interval in seconds |

Unset optional variables are omitted from the generated JSON so Gamja keeps its upstream defaults. Invalid auth, boolean, port, ping, or control-character-containing text values cause the container to fail fast instead of serving malformed configuration.

The generated nginx configuration and Gamja configuration both live under `/tmp`, preserving read-only-root-filesystem compatibility.

## Complete Gamja + soju example

A self-contained reference deployment is available in `examples/soju/`:

```sh
cd examples/soju
docker compose up -d
```

It starts soju and Gamja on a private shared container network and exposes only Gamja on host port 8080. Create the first soju user with:

```sh
docker compose exec soju sojudb -config /etc/soju/config create-user <username> -admin
docker compose restart soju
```

Put the public Gamja endpoint behind HTTPS before exposing it to untrusted networks.

## Podman Quadlet

Reference rootless Quadlet units are in `examples/quadlet/`.

```sh
mkdir -p ~/.config/containers/systemd
mkdir -p ~/.local/share/gamja-soju/data
cp examples/quadlet/*.container examples/quadlet/*.network ~/.config/containers/systemd/
cp examples/soju/soju.conf ~/.local/share/gamja-soju/soju.conf
systemctl --user daemon-reload
systemctl --user start gamja.service
```

Additional `Environment=GAMJA_...` lines can be added to `gamja.container` for runtime overrides.

## Build locally

```sh
docker build -t gamja:local .
```

Override the pinned upstream revision only when deliberately testing another commit:

```sh
docker build --build-arg GAMJA_COMMIT=<commit> -t gamja:test .
```

## Security/runtime notes

The runtime uses unprivileged nginx on port 8080. Supplied deployments use a read-only root filesystem, `/tmp` for transient runtime state, and `no-new-privileges`.

Gamja itself is a browser client. Serve the site and WebSocket endpoint over HTTPS/WSS outside trusted local testing.

## CI qualification

CI validates:

- amd64 runtime smoke test
- non-root execution
- read-only root filesystem
- health check
- default generated Gamja configuration
- all supported M1.0 environment overrides
- rejection of invalid runtime configuration
- a real WebSocket upgrade through `Gamja -> nginx /socket -> soju`
- published linux/amd64 and linux/arm64 OCI manifests
- OCI license metadata
- pinned GitHub Actions/QEMU/BuildKit tooling
- SBOM generation
- BuildKit provenance with `mode=max`

## Releases

Releases use semantic tags such as `v0.1.0`. A tag publishes the full version plus major/minor aliases. `latest` is produced from the qualified default branch.

The complete release gate and procedure are documented in `RELEASE.md`. Published release tags are treated as immutable; fixes are released under a new version.

## License and upstream

- Gamja: https://github.com/Libera-Chat/gamja
- soju: https://soju.im/
- Repository license: AGPL-3.0-only

Gamja is distributed under AGPLv3. This repository builds a pinned upstream revision and retains that licensing model. Published OCI metadata explicitly records `org.opencontainers.image.licenses=AGPL-3.0-only`.
