# Production Podman/Quadlet deployment

M1.5 mirrors the Docker Compose production architecture with system-level Podman Quadlet units:

```text
Internet :80/:443
       |
     Caddy
       |
   Gamja :8080
       |
   /socket
       |
    soju :8080
```

Only Caddy publishes host ports. Soju and Gamja remain private on the `gamja-production` Podman network.

## Install

```sh
sudo mkdir -p /etc/gamja /etc/containers/systemd
sudo cp soju.conf Caddyfile /etc/gamja/
sudo cp gamja.env.example /etc/gamja/gamja.env
sudo cp *.container *.network *.volume /etc/containers/systemd/
sudo $EDITOR /etc/gamja/gamja.env
sudo systemctl daemon-reload
sudo systemctl start caddy.service
```

Starting `caddy.service` pulls in Gamja and soju. Gamja waits for the soju healthcheck before it starts, and Caddy waits for the Gamja healthcheck.

Set `GAMJA_DOMAIN` to a DNS hostname that resolves to the server. This system-level deployment intentionally binds 80/tcp, 443/tcp and 443/udp directly. For a rootless deployment, use unprivileged host ports or configure the host's privileged-port policy explicitly.

Create the first administrator after soju is healthy:

```sh
sudo podman exec -it soju sojudb -config /etc/soju/config create-user <username> -admin
sudo systemctl restart soju.service
```

## Persistence

Quadlet-managed named volumes are:

- `gamja-soju-data`
- `gamja-caddy-data`
- `gamja-caddy-config`

The Soju and Caddy dependency images are pinned by OCI index digest. The Gamja image tracks this repository's `latest` build so the example follows the current container implementation.

## Validation

M1.5 CI installs Podman on Ubuntu 24.04, runs the Quadlet generator, starts the generated systemd units, and verifies service ordering, health, private application ports, HTTPS delivery and WSS upgrade through Caddy -> Gamja -> soju.
