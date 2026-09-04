# Gamja container

A small, reproducible, multi-architecture OCI image for [Gamja](https://github.com/Libera-Chat/gamja), the IRC web client commonly paired with [soju](https://soju.im/).

This repository packages upstream Gamja; it is not the upstream Gamja project.

## Image

```text
ghcr.io/ploos-as/gamja:latest
```

Targets and production properties:

- linux/amd64 and linux/arm64
- non-root runtime with explicit UID 101
- read-only-root-filesystem friendly; no Node.js in runtime
- reproducible pinned upstream source and immutable dependency pins
- SBOM plus BuildKit provenance (`mode=max`)
- release-blocking Trivy security qualification and daily re-scan
- strict tag -> workflow commit -> OCI revision release-integrity gate
- M1.11 keyless Cosign signatures bound to the GitHub Actions OIDC workflow identity
- runtime Gamja configuration through environment variables
- qualified HTTPS/WSS reverse proxies, production Compose and Podman Quadlet deployments

The current build is pinned to upstream commit `0f273b96994fb32b3a1b868d4b59229285f3455c`. M1.9 reports upstream drift without automatic source changes; M1.10 continuously qualifies external dependency pins without automatic upgrades.

## Architecture

```text
Browser -> HTTPS/WSS -> Caddy/nginx -> Gamja :8080 -> /socket -> soju -> IRC networks
```

The container generates `/config.json` at startup under `/tmp` and serves it through nginx. No image rebuild is required for normal Gamja server configuration.

## Quick start

With soju reachable as `soju:8080` on the same container network:

```sh
docker compose up -d
```

Then open `http://localhost:8080`.

Example override:

```sh
GAMJA_NICK='guest*' GAMJA_AUTOJOIN='#gamja,#soju' GAMJA_AUTOCONNECT=true docker compose up -d
```

## Production stack

`examples/production/` is the qualified Internet-facing reference deployment with Caddy, Gamja and soju. Only Caddy publishes host ports.

```sh
cd examples/production
cp .env.example .env
$EDITOR .env
docker compose up -d
```

Set `GAMJA_DOMAIN` to a public DNS hostname pointing at the host. TCP 80/443 must be reachable; UDP 443 is also published for HTTP/3. Create the first soju administrator after the stack is healthy:

```sh
docker compose exec soju sojudb -config /etc/soju/config create-user <username> -admin
docker compose restart soju
```

See `examples/production/README.md` and `examples/production/OPERATIONS.md`.

## Runtime configuration

Proxy variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SOJU_HOST` | `soju` | soju service DNS name/address |
| `SOJU_PORT` | `8080` | soju HTTP/WebSocket port |

Gamja variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `GAMJA_SERVER_URL` | `/socket` | WebSocket URL/path |
| `GAMJA_AUTH` | `optional` | `mandatory`, `optional`, `disabled`, `external`, or `oauth2` |
| `GAMJA_AUTOJOIN` | unset | channel or comma-separated channel list |
| `GAMJA_NICK` | unset | default nickname |
| `GAMJA_AUTOCONNECT` | unset | `true` or `false` |
| `GAMJA_PING` | unset | non-negative PING interval in seconds |
| `GAMJA_OAUTH2_URL` | unset | OAuth 2.0 authorization server URL |
| `GAMJA_OAUTH2_CLIENT_ID` | unset | OAuth 2.0 client ID |
| `GAMJA_OAUTH2_CLIENT_SECRET` | unset | OAuth 2.0 client secret when required |
| `GAMJA_OAUTH2_SCOPE` | unset | OAuth 2.0 scope |

A comma-separated `GAMJA_AUTOJOIN` is emitted as an array; one channel remains an upstream-compatible string. OAuth2 fields are emitted only when configured. Gamja is a browser application, so values emitted into `/config.json`, including `client_secret`, are browser-visible and must not be treated as server-side secrets. Invalid values fail fast.

## Deployment examples

- `examples/soju/`: simple non-TLS Gamja + soju stack
- `examples/reverse-proxy/`: qualified Caddy and nginx HTTPS/WSS configs
- `examples/production/`: production Compose stack
- `examples/quadlet/`: simple rootless Podman Quadlet example
- `examples/quadlet-production/`: qualified system-level production Quadlet stack

## Build locally

```sh
docker build -t gamja:local .
```

Override upstream only for deliberate testing:

```sh
docker build --build-arg GAMJA_COMMIT=<commit> -t gamja:test .
```

## Security and supply chain

The runtime uses unprivileged nginx on port 8080. Supplied deployments use a read-only root filesystem, `/tmp` for transient state and `no-new-privileges` where compatible.

M1.7 scans the final runtime image for fixable HIGH/CRITICAL vulnerabilities and the repository for HIGH/CRITICAL secrets/misconfigurations. M1.8 binds release tags to the exact workflow commit and OCI revision. M1.9 qualifies the upstream source pin. M1.10 qualifies external OCI and GitHub Action dependencies.

M1.11 signs every published OCI digest with Cosign keyless signing using the short-lived GitHub Actions OIDC identity, then immediately verifies the signature against the expected `Ploos-AS/gamja` `container.yml` workflow identity and GitHub Actions OIDC issuer. No long-lived signing key is stored. See `SIGNING.md` for the verification command and trust model.

## CI qualification

CI covers runtime/non-root/read-only health, generated configuration, real Gamja-to-soju WebSocket upgrades, Caddy/nginx HTTPS/WSS, production Compose and Quadlet runtime behavior, crash recovery, backup/restore, security scanning, release integrity, upstream/dependency drift, amd64/arm64 OCI manifests, SBOM, provenance and M1.11 keyless signature creation plus verification.

## Releases

Release tags use an OCI-compatible SemVer subset such as `v0.2.0` or `v0.2.0-rc.1`. Build metadata (`+...`) is rejected because it cannot map losslessly to an OCI tag. Stable tags publish full version plus major/minor aliases; `latest` is produced from qualified `main`.

Published release tags are immutable. The complete release procedure is in `RELEASE.md`; signature verification is documented in `SIGNING.md`.

## License and upstream

- Gamja upstream: https://github.com/Libera-Chat/gamja
- soju: https://soju.im/
- Repository license: AGPL-3.0-only

Gamja is distributed under AGPLv3. This repository builds a pinned upstream revision and retains that licensing model.
