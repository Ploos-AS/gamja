# Production Compose deployment

This is the M1.3 reference deployment for an Internet-facing Gamja + soju installation.

## Layout

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

Only Caddy publishes host ports. Gamja and soju remain private on the Compose network.

## Start

```sh
cp .env.example .env
$EDITOR .env
docker compose up -d
```

Set `GAMJA_DOMAIN` to a DNS hostname that resolves to the host. TCP ports 80 and 443 must be reachable for normal public certificate issuance. UDP 443 is also published for HTTP/3.

Create the initial soju administrator after the stack is healthy:

```sh
docker compose exec soju sojudb -config /etc/soju/config create-user <username> -admin
docker compose restart soju
```

## Persistence

The stack uses named volumes for:

- `soju-data`: soju SQLite database and state
- `caddy-data`: certificates and Caddy runtime data
- `caddy-config`: Caddy configuration state

Do not remove `soju-data` unless you intend to remove the soju database.

## Security

Gamja and soju do not publish host ports in this stack. All browser traffic enters through Caddy over HTTPS/WSS. Gamja retains its read-only root filesystem and `/tmp` tmpfs model.

OAuth2 values emitted into Gamja's `/config.json` are visible to the browser. `GAMJA_OAUTH2_CLIENT_SECRET` must therefore not be treated as a private server-side secret.

## Validation

M1.3 CI starts an equivalent three-service stack with Caddy internal TLS and verifies:

- soju health before Gamja dependency startup
- no published Gamja or soju application ports
- HTTP to HTTPS redirect
- HTTPS delivery of the Gamja application
- WSS upgrade through Caddy -> Gamja -> soju
- persistent soju volume wiring
