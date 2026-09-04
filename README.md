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

The current build is pinned to upstream commit:

```text
0f273b96994fb32b3a1b868d4b59229285f3455c
```

## Quick start

```sh
docker compose up -d
```

Then open `http://localhost:8080`.

Gamja requires an IRC server or bouncer that exposes IRC over WebSocket. The default configuration points Gamja at `/socket`.

## Using with soju

Gamja is especially well suited to soju. Configure a WebSocket listener in soju, for example:

```text
listen ws+insecure://127.0.0.1:8080
```

Then use your reverse proxy to route the public Gamja `/socket` path to that soju listener.

```text
Browser -> reverse proxy -> Gamja static files
                         -> /socket -> soju WebSocket listener -> IRC networks
```

## Configuration

Gamja reads `config.json` from the web root. This repository ships a conservative default:

```json
{
  "server": {
    "url": "/socket",
    "auth": "optional"
  }
}
```

For runtime configuration, bind-mount your own file read-only:

```yaml
services:
  gamja:
    volumes:
      - ./config.json:/usr/share/nginx/html/config.json:ro
```

Useful upstream options include `server.url`, `server.autojoin`, `server.auth`, `server.nick`, `server.autoconnect`, and `server.ping`.

## Build locally

```sh
docker build -t gamja:local .
```

Override the pinned upstream revision only when deliberately testing another commit:

```sh
docker build --build-arg GAMJA_COMMIT=<commit> -t gamja:test .
```

## Security/runtime notes

The runtime uses an unprivileged nginx image and listens on port 8080. The supplied Compose file enables a read-only root filesystem, temporary writable nginx paths, and `no-new-privileges`.

Gamja itself is a browser client. Serve the site and WebSocket endpoint over HTTPS/WSS outside trusted local testing.

## Upstream

- Gamja: https://github.com/Libera-Chat/gamja
- soju: https://soju.im/

Gamja is licensed under AGPLv3. See upstream for the application license and source.
