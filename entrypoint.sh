#!/bin/sh
set -eu

SOJU_HOST="${SOJU_HOST:-soju}"
SOJU_PORT="${SOJU_PORT:-8080}"

case "$SOJU_HOST" in
  *[!A-Za-z0-9._-]*|'')
    echo "Invalid SOJU_HOST: $SOJU_HOST" >&2
    exit 1
    ;;
esac

case "$SOJU_PORT" in
  *[!0-9]*|'')
    echo "Invalid SOJU_PORT: $SOJU_PORT" >&2
    exit 1
    ;;
esac

DNS_RESOLVER="$(awk '/^nameserver[[:space:]]+/ { print $2; exit }' /etc/resolv.conf)"
if [ -z "$DNS_RESOLVER" ]; then
  echo "Unable to determine DNS resolver from /etc/resolv.conf" >&2
  exit 1
fi

sed \
  -e "s/__DNS_RESOLVER__/$DNS_RESOLVER/g" \
  -e "s/__SOJU_HOST__/$SOJU_HOST/g" \
  -e "s/__SOJU_PORT__/$SOJU_PORT/g" \
  /etc/gamja/nginx.conf.template > /tmp/nginx.conf

exec nginx -c /tmp/nginx.conf -g 'daemon off;'
