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
- pinned QEMU/binfmt release with only arm64 enabled
- pinned BuildKit release
- explicit OCI license metadata
- SBOM and BuildKit provenance on published images

The current build is pinned to upstream commit:

```text
0f273b96994fb32b3a1b868d4b59229285f3455c
```

The current release base images are pinned by multi-platform index digest in the Dockerfile. CI additionally pins `tonistiigi/binfmt` to `qemu-v10.2.3` and BuildKit to `v0.32.2` rather than using their floating defaults.

## Architecture

The container serves the Gamja frontend and proxies Gamja's default `/socket` endpoint to a soju WebSocket listener:

```text
Browser -> Gamja/nginx :8080 -> /socket -> soju WebSocket -> IRC networks
```

Upstream Gamja requires an IRC WebSocket server, and upstream recommends proxying `/socket` to soju. This image includes that proxy path directly.

## Quick start

If a soju container named `soju` is reachable on the same container network and listens for HTTP/WebSocket traffic on port 8080:

```sh
docker compose up -d
```

Then open `http://localhost:8080`.

The supplied `compose.yaml` supports:

```text
GAMJA_PORT=8080
SOJU_HOST=soju
SOJU_PORT=8080
```

For example:

```sh
SOJU_HOST=my-soju SOJU_PORT=8080 GAMJA_PORT=8088 docker compose up -d
```

## Complete Gamja + soju example

A self-contained reference deployment is available in `examples/soju/`.

```sh
cd examples/soju
docker compose up -d
```

It starts:

- `ghcr.io/ploos-as/soju:latest`
- `ghcr.io/ploos-as/gamja:latest`
- a private shared container network
- persistent soju state
- a soju HTTP/WebSocket listener on port 8080, reachable only from the container network
- Gamja exposed on host port 8080

The browser reaches only Gamja. nginx proxies `/socket` internally to soju.

Create the first soju user with:

```sh
docker compose exec soju sojudb -config /etc/soju/config create-user <username> -admin
docker compose restart soju
```

The example is intended as a local reference deployment. Put the public Gamja endpoint behind HTTPS before exposing it to untrusted networks.

## Runtime proxy configuration

The `/socket` proxy is configured at container startup.

Environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SOJU_HOST` | `soju` | DNS name or address of the soju service |
| `SOJU_PORT` | `8080` | soju HTTP/WebSocket listener port |

The generated nginx configuration is stored under `/tmp`, so the image remains compatible with a read-only root filesystem.

## Gamja configuration

Gamja reads `config.json` from the web root. This repository ships:

```json
{
  "server": {
    "url": "/socket",
    "auth": "optional"
  }
}
```

To replace it, bind-mount your own file read-only:

```yaml
services:
  gamja:
    volumes:
      - ./config.json:/usr/share/nginx/html/config.json:ro
```

Useful upstream options include `server.url`, `server.autojoin`, `server.auth`, `server.nick`, `server.autoconnect`, and `server.ping`.

## Podman Quadlet

Reference rootless Quadlet units are in `examples/quadlet/`.

Install them for the current user:

```sh
mkdir -p ~/.config/containers/systemd
mkdir -p ~/.local/share/gamja-soju/data
cp examples/quadlet/*.container examples/quadlet/*.network ~/.config/containers/systemd/
cp examples/soju/soju.conf ~/.local/share/gamja-soju/soju.conf
systemctl --user daemon-reload
systemctl --user start gamja.service
```

To start the stack automatically when the user systemd instance starts:

```sh
systemctl --user enable gamja.service
```

For persistent user services across logout/reboot, enable lingering for the deployment account as appropriate on the host.

The Quadlet deployment mirrors the Compose model:

```text
gamja.service
   |
   +-- gamja-irc network
   |
   `-- /socket -> soju.service:8080
```

Both containers run without privileged networking or a Docker/Podman socket mount.

## Build locally

```sh
docker build -t gamja:local .
```

Override the pinned upstream revision only when deliberately testing another commit:

```sh
docker build --build-arg GAMJA_COMMIT=<commit> -t gamja:test .
```

## Security/runtime notes

The runtime uses an unprivileged nginx image and listens on port 8080. The supplied deployments use a read-only root filesystem for Gamja, `/tmp` for transient runtime state, and `no-new-privileges`.

Gamja itself is a browser client. Serve the site and WebSocket endpoint over HTTPS/WSS outside trusted local testing.

## CI qualification

CI validates:

- amd64 runtime smoke test
- non-root execution
- read-only root filesystem
- health check
- OCI license label equals `AGPL-3.0-only`
- a real WebSocket upgrade through `Gamja -> nginx /socket -> soju`
- published linux/amd64 and linux/arm64 OCI manifests
- pinned GitHub Actions by commit SHA
- pinned QEMU/binfmt release with only arm64 installed
- pinned BuildKit release
- SBOM generation for published images
- BuildKit provenance with `mode=max`

## Releases

Releases use semantic tags such as `v0.1.0`. A tag publishes the full version plus major/minor aliases. `latest` is produced from the qualified default branch.

The complete release gate and procedure are documented in `RELEASE.md`. Published release tags are treated as immutable; fixes are released under a new version.

## License and upstream

- Gamja: https://github.com/Libera-Chat/gamja
- soju: https://soju.im/
- Repository license: AGPL-3.0-only

Gamja is distributed under AGPLv3. This repository builds a pinned upstream revision and retains that licensing model. Published OCI metadata explicitly records `org.opencontainers.image.licenses=AGPL-3.0-only`.
