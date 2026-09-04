#!/bin/sh
set -eu

SOJU_HOST="${SOJU_HOST:-soju}"
SOJU_PORT="${SOJU_PORT:-8080}"
GAMJA_SERVER_URL="${GAMJA_SERVER_URL:-/socket}"
GAMJA_AUTH="${GAMJA_AUTH:-optional}"
GAMJA_AUTOJOIN="${GAMJA_AUTOJOIN:-}"
GAMJA_NICK="${GAMJA_NICK:-}"
GAMJA_AUTOCONNECT="${GAMJA_AUTOCONNECT:-}"
GAMJA_PING="${GAMJA_PING:-}"

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

if [ "$SOJU_PORT" -lt 1 ] || [ "$SOJU_PORT" -gt 65535 ]; then
  echo "SOJU_PORT must be between 1 and 65535" >&2
  exit 1
fi

case "$GAMJA_AUTH" in
  mandatory|optional|disabled|external|oauth2) ;;
  *)
    echo "Invalid GAMJA_AUTH: $GAMJA_AUTH" >&2
    exit 1
    ;;
esac

if [ -n "$GAMJA_AUTOCONNECT" ]; then
  case "$GAMJA_AUTOCONNECT" in
    true|false) ;;
    *)
      echo "GAMJA_AUTOCONNECT must be true or false" >&2
      exit 1
      ;;
  esac
fi

if [ -n "$GAMJA_PING" ]; then
  case "$GAMJA_PING" in
    *[!0-9]*)
      echo "GAMJA_PING must be a non-negative integer" >&2
      exit 1
      ;;
  esac
fi

validate_text() {
  name="$1"
  value="$2"
  if printf '%s' "$value" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo "$name must not contain control characters" >&2
    exit 1
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

validate_text GAMJA_SERVER_URL "$GAMJA_SERVER_URL"
validate_text GAMJA_AUTOJOIN "$GAMJA_AUTOJOIN"
validate_text GAMJA_NICK "$GAMJA_NICK"

server_url="$(json_escape "$GAMJA_SERVER_URL")"
auth="$(json_escape "$GAMJA_AUTH")"

{
  printf '{\n  "server": {\n'
  printf '    "url": "%s",\n' "$server_url"
  printf '    "auth": "%s"' "$auth"

  if [ -n "$GAMJA_AUTOJOIN" ]; then
    printf ',\n    "autojoin": "%s"' "$(json_escape "$GAMJA_AUTOJOIN")"
  fi
  if [ -n "$GAMJA_NICK" ]; then
    printf ',\n    "nick": "%s"' "$(json_escape "$GAMJA_NICK")"
  fi
  if [ -n "$GAMJA_AUTOCONNECT" ]; then
    printf ',\n    "autoconnect": %s' "$GAMJA_AUTOCONNECT"
  fi
  if [ -n "$GAMJA_PING" ]; then
    printf ',\n    "ping": %s' "$GAMJA_PING"
  fi

  printf '\n  }\n}\n'
} > /tmp/gamja-config.json

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
