#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <image@sha256:digest>" >&2
  exit 2
}

[ "$#" -eq 1 ] || usage
image_ref="$1"

case "$image_ref" in
  *@sha256:????????????????????????????????????????????????????????????????) ;;
  *) echo "image reference must be digest-bound: $image_ref" >&2; exit 2 ;;
esac

for cmd in docker curl grep; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "required command not found: $cmd" >&2; exit 2; }
done

soju_image='ghcr.io/ploos-as/soju:latest@sha256:ae1eb58d75beea7bfbeff3f004700289f2fcd4c56da671d88216f2cfb2d1d491'
suffix="${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-$$"
network="gamja-release-runtime-$suffix"
gamja_container="gamja-release-runtime-$suffix"
soju_container="soju-release-runtime-$suffix"
soju_config="$(mktemp)"
index_file="$(mktemp)"
config_file="$(mktemp)"
headers_file="$(mktemp)"
body_file="$(mktemp)"

cleanup() {
  docker rm -f "$gamja_container" "$soju_container" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  rm -f "$soju_config" "$index_file" "$config_file" "$headers_file" "$body_file"
}
trap cleanup EXIT

fail() {
  echo "release runtime qualification failed: $*" >&2
  docker inspect "$gamja_container" >/dev/null 2>&1 && docker logs "$gamja_container" >&2 || true
  docker inspect "$soju_container" >/dev/null 2>&1 && docker logs "$soju_container" >&2 || true
  exit 1
}

cat >"$soju_config" <<'EOF'
db sqlite3 /var/lib/soju/main.db
listen http+insecure://0.0.0.0:8080
EOF

# Pull the immutable release identity explicitly. The CI runner is amd64; the
# multi-platform index digest selects the amd64 manifest for the runtime gate.
docker pull --platform linux/amd64 "$image_ref" >/dev/null
docker pull --platform linux/amd64 "$soju_image" >/dev/null

docker network create "$network" >/dev/null

docker run -d \
  --name "$soju_container" \
  --network "$network" \
  --network-alias soju \
  --read-only \
  --tmpfs /var/lib/soju:rw,noexec,nosuid,nodev \
  --security-opt no-new-privileges:true \
  -v "$soju_config:/etc/soju/release-runtime.conf:ro" \
  "$soju_image" -config /etc/soju/release-runtime.conf >/dev/null

docker run -d \
  --name "$gamja_container" \
  --network "$network" \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,nodev \
  --security-opt no-new-privileges:true \
  "$image_ref" >/dev/null

# Runtime identity/security contract: expected UID 101, read-only rootfs and NNP.
actual_user="$(docker inspect --format '{{.Config.User}}' "$gamja_container")"
[ "$actual_user" = "101" ] || fail "expected image user 101, got '$actual_user'"
readonly_rootfs="$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$gamja_container")"
[ "$readonly_rootfs" = "true" ] || fail "expected read-only root filesystem, got '$readonly_rootfs'"
security_opts="$(docker inspect --format '{{json .HostConfig.SecurityOpt}}' "$gamja_container")"
grep -q 'no-new-privileges' <<<"$security_opts" || fail "no-new-privileges missing from SecurityOpt: $security_opts"

# Wait for nginx/health without publishing a host port; probe from the same
# network using the container IP so the exact release image remains isolated.
for _ in $(seq 1 30); do
  health="$(docker inspect --format '{{.State.Health.Status}}' "$gamja_container")"
  [ "$health" = "healthy" ] && break
  [ "$health" != "unhealthy" ] || fail "container health became unhealthy"
  sleep 1
done
health="$(docker inspect --format '{{.State.Health.Status}}' "$gamja_container")"
[ "$health" = "healthy" ] || fail "container did not become healthy; final health='$health'"

gamja_ip="$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$gamja_container")"
[ -n "$gamja_ip" ] || fail "container has no network IP"

curl --fail --silent --show-error "http://$gamja_ip:8080/" >"$index_file" || fail "Gamja index probe failed"
curl --fail --silent --show-error "http://$gamja_ip:8080/config.json" >"$config_file" || fail "Gamja config probe failed"
grep -q '<title>gamja IRC client</title>' "$index_file" || fail "Gamja index title mismatch"
grep -q '"url": "/socket"' "$config_file" || fail "generated config does not target /socket"

# A real RFC 6455 upgrade through Gamja/nginx to soju proves the release
# artifact's built-in /socket proxy path, not merely static-file serving.
curl --http1.1 --max-time 2 --silent --show-error \
  -D "$headers_file" -o "$body_file" \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  "http://$gamja_ip:8080/socket" || true

grep -Eq '^HTTP/1\.[01] 101 ' "$headers_file" || fail "WebSocket proxy did not return HTTP 101"
grep -qi '^Upgrade: websocket' "$headers_file" || fail "WebSocket Upgrade response header missing"
grep -qi '^Connection: upgrade' "$headers_file" || fail "WebSocket Connection upgrade response header missing"

echo "release_runtime=verified"
echo "image=$image_ref"
echo "platform=linux/amd64"
echo "user=101"
echo "read_only=true"
echo "health=healthy"
echo "config=/socket"
echo "websocket_upgrade=101"
