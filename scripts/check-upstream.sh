#!/bin/sh
set -eu

UPSTREAM_REPO=${UPSTREAM_REPO:-Libera-Chat/gamja}
UPSTREAM_BRANCH=${UPSTREAM_BRANCH:-production}
PINNED_COMMIT=${PINNED_COMMIT:-0f273b96994fb32b3a1b868d4b59229285f3455c}
API_URL=${UPSTREAM_API_URL:-https://api.github.com/repos/${UPSTREAM_REPO}/commits/${UPSTREAM_BRANCH}}

case "$PINNED_COMMIT" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "invalid pinned commit: $PINNED_COMMIT" >&2; exit 2 ;;
esac

json=$(curl --fail --silent --show-error \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$API_URL")

latest=$(printf '%s\n' "$json" | jq -r '.sha // empty')
case "$latest" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "upstream API returned no valid commit SHA" >&2; exit 3 ;;
esac

printf 'upstream_repo=%s\n' "$UPSTREAM_REPO"
printf 'upstream_branch=%s\n' "$UPSTREAM_BRANCH"
printf 'pinned_commit=%s\n' "$PINNED_COMMIT"
printf 'latest_commit=%s\n' "$latest"

if [ "$latest" = "$PINNED_COMMIT" ]; then
  printf 'status=current\n'
  exit 0
fi

printf 'status=update-available\n'
exit 10
