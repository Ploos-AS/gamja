# Production Compose deployment

This is the M1.4+ production reference deployment for an Internet-facing Gamja + soju installation, with the M1.6 operations baseline.

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

## Operations baseline

M1.6 adds bounded local logging, resource guardrails and explicit shutdown windows:

| Service | CPU | Memory | PIDs | Stop grace |
| --- | ---: | ---: | ---: | ---: |
| soju | 1 CPU | 256 MiB | 256 | 30s |
| Gamja | 0.5 CPU | 128 MiB | 128 | 15s |
| Caddy | 1 CPU | 256 MiB | 256 | 30s |

Docker logs use `json-file` rotation with 10 MiB per file and three files per service. These values are a small-installation baseline, not fixed sizing requirements; tune them from observed workload.

See `OPERATIONS.md` for status, logs, health, resource inspection, restart/recovery, upgrade and incident-triage commands.

## Supply-chain pins

Production dependencies are intentionally pinned by OCI index digest:

- soju: `ghcr.io/ploos-as/soju:latest@sha256:ae1eb58d75beea7bfbeff3f004700289f2fcd4c56da671d88216f2cfb2d1d491`
- Caddy: `caddy:2.11.4-alpine@sha256:5f5c8640aae01df9654968d946d8f1a56c497f1dd5c5cda4cf95ab7c14d58648`

The human-readable tag documents the intended version while the digest makes deployment reproducible. Updating either dependency is an explicit maintenance action: inspect the new multi-platform index, update the tag and digest together, then require the production-stack CI gate to pass.

Gamja uses this repository's `latest` image because this example tracks the current Gamja container produced by the same repository.

## Health and startup ordering

The production Compose file health-checks all three services:

- soju validates database/config access with `sojudb`
- Gamja verifies its local HTTP endpoint
- Caddy verifies its local admin API

Gamja starts only after soju is healthy. Caddy starts only after Gamja is healthy. This makes dependency failures visible to Compose instead of presenting a partially started public stack.

Check status with:

```sh
docker compose ps
```

## Persistence

The stack uses named volumes for:

- `soju-data`: soju SQLite database and state
- `caddy-data`: certificates and Caddy runtime data
- `caddy-config`: Caddy configuration state

Do not remove `soju-data` unless you intend to remove the soju database. Caddy can recreate state, but preserving its volumes avoids unnecessary certificate re-issuance and keeps deployment state intact.

## Backup

For a consistent snapshot, `backup.sh` stops the three services, archives all persistent volumes, records SHA-256 checksums, and starts the stack again:

```sh
sh backup.sh
```

Backups are written below `./backups/<UTC timestamp>/` and contain:

```text
soju-data.tgz
caddy-data.tgz
caddy-config.tgz
SHA256SUMS
```

An alternate backup root can be supplied:

```sh
sh backup.sh /srv/backups/gamja
```

Copy the resulting backup directory to storage outside the Docker host. A backup kept only on the same host is not sufficient disaster recovery.

## Restore

Restoring is destructive to the current persistent state. First stop normal writes and select a known-good backup. `restore.sh` verifies `SHA256SUMS`, stops the stack, replaces the three persisted data sets, and starts the services again:

```sh
sh restore.sh ./backups/20260904T203000Z
```

After restore, validate:

```sh
docker compose ps
docker compose logs --tail=100 soju gamja caddy
```

Then verify browser login and a WebSocket-backed IRC connection.

## Security

Gamja and soju do not publish host ports in this stack. All browser traffic enters through Caddy over HTTPS/WSS. Gamja retains its read-only root filesystem and `/tmp` tmpfs model. All three Compose services use `no-new-privileges`.

OAuth2 values emitted into Gamja's `/config.json` are visible to the browser. `GAMJA_OAUTH2_CLIENT_SECRET` must therefore not be treated as a private server-side secret.

## Validation

CI verifies the production dependency pins and starts an equivalent three-service stack with Caddy internal TLS. It proves:

- pinned soju and Caddy OCI indexes resolve
- soju -> Gamja -> Caddy health ordering
- no published Gamja or soju application ports
- HTTP to HTTPS redirect
- HTTPS delivery of the Gamja application
- WSS upgrade through Caddy -> Gamja -> soju
- persistent soju and Caddy volume wiring
- backup archive creation and checksums
- destructive restore recovers a marker from `soju-data`
- M1.6 Compose resource, logging and shutdown policy renders correctly
