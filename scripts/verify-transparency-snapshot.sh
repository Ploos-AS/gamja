#!/bin/sh
set -eu

index=${1:-}
checksum=${2:-}
bundle=${3:-}
root=${4:-}
if [ -z "$index" ] || [ -z "$checksum" ] || [ -z "$bundle" ] || [ "${5:-}" ]; then
  echo "usage: $0 <release-index.json> <release-index.json.sha256> <release-index.bundle.json> [release-assets-root]" >&2
  exit 2
fi

command -v cosign >/dev/null 2>&1 || { echo "cosign is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }

test -s "$index" || { echo "missing or empty transparency index: $index" >&2; exit 1; }
test -s "$checksum" || { echo "missing or empty transparency checksum: $checksum" >&2; exit 1; }
test -s "$bundle" || { echo "missing or empty transparency signature bundle: $bundle" >&2; exit 1; }

index_dir=$(CDPATH= cd -- "$(dirname -- "$index")" && pwd)
checksum_dir=$(CDPATH= cd -- "$(dirname -- "$checksum")" && pwd)
bundle_dir=$(CDPATH= cd -- "$(dirname -- "$bundle")" && pwd)
[ "$index_dir" = "$checksum_dir" ] && [ "$index_dir" = "$bundle_dir" ] || {
  echo "transparency index, checksum and bundle must share a directory" >&2
  exit 1
}
[ "$(basename -- "$index")" = release-index.json ] || { echo "index must be named release-index.json" >&2; exit 1; }
[ "$(basename -- "$checksum")" = release-index.json.sha256 ] || { echo "checksum must be named release-index.json.sha256" >&2; exit 1; }
[ "$(basename -- "$bundle")" = release-index.bundle.json ] || { echo "bundle must be named release-index.bundle.json" >&2; exit 1; }

grep -Eq '^[0-9a-f]{64}  release-index\.json$' "$checksum" || {
  echo "invalid transparency checksum format" >&2
  exit 1
}
(cd "$index_dir" && sha256sum -c release-index.json.sha256 >/dev/null)

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -n "$root" ]; then
  sh "$script_dir/verify-release-index.sh" "$index" "$root" >/dev/null
else
  sh "$script_dir/verify-release-index.sh" "$index" >/dev/null
fi

issuer=${TRANSPARENCY_OIDC_ISSUER:-https://token.actions.githubusercontent.com}
identity=${TRANSPARENCY_IDENTITY:-https://github.com/Ploos-AS/gamja/.github/workflows/release-transparency.yml@refs/heads/main}

cosign verify-blob \
  --bundle "$bundle" \
  --certificate-oidc-issuer "$issuer" \
  --certificate-identity "$identity" \
  "$index" >/dev/null

printf 'M1.26 signed transparency snapshot verified: sha256=%s\n' "$(sha256sum "$index" | awk '{print $1}')"
