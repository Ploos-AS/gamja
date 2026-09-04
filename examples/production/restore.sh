#!/bin/sh
set -eu

backup_dir=${1:?usage: sh restore.sh BACKUP_DIRECTORY}

for file in SHA256SUMS soju-data.tgz caddy-data.tgz caddy-config.tgz; do
    test -f "$backup_dir/$file" || {
        printf '%s\n' "Missing $backup_dir/$file" >&2
        exit 1
    }
done

(
    cd "$backup_dir"
    sha256sum -c SHA256SUMS
)

restart_stack=0
cleanup() {
    if [ "$restart_stack" -eq 1 ]; then
        docker compose up -d >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM

docker compose stop caddy gamja soju
restart_stack=1

cat "$backup_dir/soju-data.tgz" | docker compose run --rm -T --no-deps --entrypoint sh soju \
    -c 'find /var/lib/soju -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; tar -C /var/lib/soju -xzf -'

cat "$backup_dir/caddy-data.tgz" | docker compose run --rm -T --no-deps --entrypoint sh caddy \
    -c 'find /data -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; tar -C /data -xzf -'

cat "$backup_dir/caddy-config.tgz" | docker compose run --rm -T --no-deps --entrypoint sh caddy \
    -c 'find /config -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; tar -C /config -xzf -'

docker compose up -d
restart_stack=0
trap - EXIT INT TERM

printf '%s\n' "Restore completed from $backup_dir"
