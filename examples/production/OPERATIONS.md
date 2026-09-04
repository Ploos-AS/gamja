# Gamja production operations runbook

This runbook covers the M1.6 operational baseline for the Caddy -> Gamja -> soju production stack.

## Service status

```sh
docker compose ps
docker compose top
```

All three services should be running and healthy. Only Caddy should publish host ports.

## Logs

Follow the complete request path:

```sh
docker compose logs -f --tail=100 caddy gamja soju
```

Inspect one component:

```sh
docker compose logs --since=30m soju
docker compose logs --since=30m gamja
docker compose logs --since=30m caddy
```

The reference Compose deployment uses Docker's `json-file` driver with rotation at 10 MiB and three files per service. This bounds local container log growth while retaining a short troubleshooting window. Long-term log retention should be handled by the host or a dedicated log collector.

## Health

```sh
for service in soju gamja caddy; do
  id="$(docker compose ps -q "$service")"
  printf '%-8s ' "$service"
  docker inspect --format '{{.State.Health.Status}}' "$id"
done
```

Expected result is `healthy` for each service.

## Resource usage and limits

Live usage:

```sh
docker stats
```

Configured baseline limits:

| Service | CPU | Memory | PIDs |
| --- | ---: | ---: | ---: |
| soju | 1 CPU | 256 MiB | 256 |
| Gamja | 0.5 CPU | 128 MiB | 128 |
| Caddy | 1 CPU | 256 MiB | 256 |

These are conservative guardrails for a small installation, not sizing guarantees. Raise them when real workload measurements justify it. In particular, larger soju deployments may require more memory and CPU as users, networks and retained state grow.

Inspect the active limits:

```sh
for service in soju gamja caddy; do
  id="$(docker compose ps -q "$service")"
  echo "== $service =="
  docker inspect --format 'memory={{.HostConfig.Memory}} nano_cpus={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} log={{.HostConfig.LogConfig.Type}}' "$id"
done
```

## Restart and recovery

Restart one component without destroying data:

```sh
docker compose restart soju
docker compose restart gamja
docker compose restart caddy
```

Recreate after a configuration change:

```sh
docker compose up -d --wait
```

Do not use `docker compose down -v` during normal operations because `-v` removes the named persistent volumes.

## Upgrade

1. Update image tag and digest together for pinned dependencies.
2. Pull images.
3. Recreate the stack.
4. Confirm health, HTTPS and IRC/WebSocket connectivity.

```sh
docker compose pull
docker compose up -d --wait
docker compose ps
```

For soju or Caddy dependency changes, keep the OCI digest pin. Do not replace a digest-pinned production dependency with a floating tag.

## Backup before risky changes

```sh
sh backup.sh /srv/backups/gamja
```

Verify the generated `SHA256SUMS` and copy the backup off-host before destructive maintenance.

## Incident triage

If the web UI is unavailable, check from the edge inward:

```sh
docker compose ps
docker compose logs --tail=100 caddy
docker compose logs --tail=100 gamja
docker compose logs --tail=100 soju
```

Then test the public endpoint and runtime config:

```sh
curl -I https://$GAMJA_DOMAIN/
curl -fsS https://$GAMJA_DOMAIN/config.json
```

If the page loads but IRC does not connect, focus on `/socket`, Gamja's `SOJU_HOST`/`SOJU_PORT`, soju health, and the Caddy/Gamja WebSocket path rather than the static frontend.
