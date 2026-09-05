#!/bin/sh
set -eu

index=${1:-}
checksum=${2:-}
bundle=${3:-}
if [ -z "$index" ] || [ -z "$checksum" ] || [ -z "$bundle" ] || [ "${4:-}" ]; then
  echo "usage: $0 <release-index.json> <release-index.json.sha256> <release-index.bundle.json>" >&2
  exit 2
fi

[ -n "${GH_TOKEN:-}" ] || { echo "GH_TOKEN is required for live release reconstruction" >&2; exit 2; }
command -v cmp >/dev/null 2>&1 || { echo "cmp is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sh "$script_dir/verify-transparency-snapshot.sh" "$index" "$checksum" "$bundle" >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
live="$tmp/release-index.json"

sh "$script_dir/collect-release-index.sh" "$live" >/dev/null
sh "$script_dir/verify-release-index.sh" "$live" >/dev/null

if ! cmp -s "$index" "$live"; then
  signed_sha=$(sha256sum "$index" | awk '{print $1}')
  live_sha=$(sha256sum "$live" | awk '{print $1}')
  echo "signed transparency snapshot does not match current live release reconstruction" >&2
  echo "signed sha256: $signed_sha" >&2
  echo "live   sha256: $live_sha" >&2
  exit 1
fi

printf 'M1.27 live transparency verified: sha256=%s\n' "$(sha256sum "$index" | awk '{print $1}')"
