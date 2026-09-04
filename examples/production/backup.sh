#!/bin/sh
set -eu

backup_root=${1:-./backups}
stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="$backup_root/$stamp"

mkdir -p "$out"

restart_stack=0
cleanup() {
    if [ "$restart_stack" -eq 1 ]; then
        docker compose up -d >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM

docker compose stop caddy gamja soju
restart_stack=1

docker compose run --rm -T --no-deps --entrypoint sh soju \
    -c 'tar -C /var/lib/soju -czf - .' >"$out/soju-data.tgz"

docker compose run --rm -T --no-deps --entrypoint sh caddy \
    -c 'tar -C /data -czf - .' >"$out/caddy-data.tgz"

docker compose run --rm -T --no-deps --entrypoint sh caddy \
    -c 'tar -C /config -czf - .' >"$out/caddy-config.tgz"

(
    cd "$out"
    sha256sum soju-data.tgz caddy-data.tgz caddy-config.tgz >SHA256SUMS
)

docker compose up -d
restart_stack=0
trap - EXIT INT TERM

printf '%s\n' "Backup written to $out"
