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
- non-root runtime with explicit UID 101
- read-only-root-filesystem friendly
- no Node.js in the runtime image
- reproducible upstream source pin
- pinned multi-platform base-image digests
- pinned GitHub Actions by commit SHA
- pinned QEMU/binfmt and BuildKit
- explicit OCI license and revision metadata
- SBOM and BuildKit provenance on published images
- release-blocking Trivy security qualification
- daily vulnerability, secret and misconfiguration re-scan
- strict tag -> workflow commit -> OCI revision release-integrity gate
- runtime Gamja configuration through environment variables
- qualified Caddy and nginx reverse-proxy examples for HTTPS/WSS deployment
- qualified production Compose stack with Caddy + Gamja + soju

The current build is pinned to upstream commit:

```text
0f273b96994fb32b3a1b868d4b59229285f3455c
```

## Architecture

```text
Browser -> Gamja/nginx :8080 -> /socket -> soju WebSocket -> IRC networks
```

For public deployments:

```text
Browser -> HTTPS/WSS -> Caddy or nginx -> Gamja :8080 -> /socket -> soju
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
GAMJA_NICK='guest*' GAMJA_AUTOJOIN='#gamja,#soju' GAMJA_AUTOCONNECT=true docker compose up -d
```

## Production stack

`examples/production/` contains the M1.3 reference deployment with soju, Gamja and Caddy. Only Caddy publishes host ports; Gamja and soju stay private on the Compose network. Soju and Caddy state use named persistent volumes.

```sh
cd examples/production
cp .env.example .env
$EDITOR .env
docker compose up -d
```

Set `GAMJA_DOMAIN` to a public DNS hostname whose A/AAAA records point at the host. TCP 80/443 must be reachable; UDP 443 is also published for HTTP/3. Caddy obtains and renews public HTTPS certificates automatically for a valid public hostname.

Create the first soju administrator after the stack is healthy:

```sh
docker compose exec soju sojudb -config /etc/soju/config create-user <username> -admin
docker compose restart soju
```

See `examples/production/README.md` for persistence, security and validation details.

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
| `GAMJA_AUTOJOIN` | unset | One channel or a comma-separated channel list |
| `GAMJA_NICK` | unset | Default nickname; `*` retains upstream random-suffix behavior |
| `GAMJA_AUTOCONNECT` | unset | `true` or `false` |
| `GAMJA_PING` | unset | Non-negative PING interval in seconds |
| `GAMJA_OAUTH2_URL` | unset | OAuth 2.0 authorization server URL |
| `GAMJA_OAUTH2_CLIENT_ID` | unset | OAuth 2.0 client ID |
| `GAMJA_OAUTH2_CLIENT_SECRET` | unset | OAuth 2.0 client secret, when required by the deployment |
| `GAMJA_OAUTH2_SCOPE` | unset | OAuth 2.0 scope |

A single `GAMJA_AUTOJOIN` value is emitted as an upstream-compatible string. A comma-separated value such as `#gamja,#soju,#ircv3` is emitted as an array of strings.

OAuth2 fields are emitted only when at least one `GAMJA_OAUTH2_*` variable is set. Because Gamja is a browser application, anything emitted into `/config.json`, including `client_secret`, is visible to the browser. Do not treat `GAMJA_OAUTH2_CLIENT_SECRET` as a server-side secret.

Unset optional variables are omitted from the generated JSON so Gamja keeps its upstream defaults. Invalid auth, boolean, port, ping, empty entries in a multi-channel autojoin list, or control-character-containing text values cause the container to fail fast instead of serving malformed configuration.

The generated nginx configuration and Gamja configuration both live under `/tmp`, preserving read-only-root-filesystem compatibility.

## Complete Gamja + soju example

A simpler non-TLS reference deployment is available in `examples/soju/`:

```sh
cd examples/soju
docker compose up -d
```

It starts soju and Gamja on a private shared container network and exposes only Gamja on host port 8080. Use `examples/production/` for Internet-facing deployment.

## HTTPS/WSS reverse proxy

Qualified standalone reference configs are in `examples/reverse-proxy/`:

- `Caddyfile`: automatic HTTPS and automatic WebSocket proxying
- `nginx.conf`: explicit TLS termination, forwarded headers, and WebSocket Upgrade/Connection handling

M1.2 CI verifies both paths with real protocol upgrades, including HTTPS/WSS through nginx.

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

Additional `Environment=GAMJA_...` lines can be added to `gamja.container` for runtime overrides, including OAuth2 fields.

## Build locally

```sh
docker build -t gamja:local .
```

Override the pinned upstream revision only when deliberately testing another commit:

```sh
docker build --build-arg GAMJA_COMMIT=<commit> -t gamja:test .
```

## Security/runtime notes

The runtime uses unprivileged nginx on port 8080 and explicitly declares UID 101 in the final Dockerfile stage. Supplied deployments use a read-only root filesystem, `/tmp` for transient runtime state, and `no-new-privileges` where applicable.

M1.7 scans the shipped runtime image for fixable `HIGH` and `CRITICAL` OS/library vulnerabilities and scans the repository for `HIGH` and `CRITICAL` secrets and misconfigurations. These checks run before GHCR publication. A dedicated daily security workflow repeats the qualification against current vulnerability intelligence. See `SECURITY.md` for the policy and scope boundary.

Gamja itself is a browser client. Serve the site and WebSocket endpoint over HTTPS/WSS outside trusted local testing. In the production Compose example only Caddy is Internet-facing; application ports remain private to the Compose network.

## CI qualification

CI validates:

- amd64 runtime smoke test
- non-root execution
- read-only root filesystem
- health check
- default generated Gamja configuration
- M1.0 server/runtime overrides
- M1.1 multi-channel autojoin
- M1.1 OAuth2 configuration generation
- rejection of invalid runtime configuration
- a real WebSocket upgrade through `Gamja -> nginx /socket -> soju`
- M1.2 Caddy reverse-proxy WebSocket upgrade
- M1.2 nginx TLS termination and WSS upgrade
- M1.3 production Compose dependency health
- M1.3 private Gamja/soju service ports
- M1.3 HTTP-to-HTTPS redirect and HTTPS application delivery
- M1.3 WSS through `Caddy -> Gamja -> soju`
- M1.3 persistent soju volume wiring
- M1.6 Compose and Quadlet operations/resource policy
- M1.6 real systemd/Podman crash-restart-recovery
- M1.7 no fixable HIGH/CRITICAL vulnerabilities in the final runtime image
- M1.7 no HIGH/CRITICAL repository secret or misconfiguration findings
- M1.7 daily continuous security re-scan
- M1.8 strict OCI-compatible release-tag validation
- M1.8 release tag commit equals the successful container workflow commit
- M1.8 OCI revision annotation equals the exact built/released commit
- published linux/amd64 and linux/arm64 OCI manifests
- OCI license metadata
- pinned GitHub Actions/QEMU/BuildKit tooling
- SBOM generation
- BuildKit provenance with `mode=max`

## Releases

Release tags use an OCI-compatible SemVer subset such as `v0.2.0` or `v0.2.0-rc.1`. Build metadata (`+...`) is rejected because it cannot map losslessly to an OCI tag. Stable tags publish the full version plus major/minor aliases. `latest` is produced from the qualified default branch.

M1.8 binds each published OCI index to its exact Git commit with `org.opencontainers.image.revision`; GitHub Release creation additionally verifies that the Git tag, successful container workflow, and OCI revision all identify the same commit.

The complete release gate and procedure are documented in `RELEASE.md`. Published release tags are treated as immutable; fixes are released under a new version.

## License and upstream

- Gamja: https://github.com/Libera-Chat/gamja
- soju: https://soju.im/
- Repository license: AGPL-3.0-only

Gamja is distributed under AGPLv3. This repository builds a pinned upstream revision and retains that licensing model. Published OCI metadata explicitly records `org.opencontainers.image.licenses=AGPL-3.0-only`.
