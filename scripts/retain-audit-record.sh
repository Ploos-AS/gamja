#!/bin/sh
set -eu

tag=${1:-}
record=${2:-}
checksum=${3:-}
if [ -z "$tag" ] || [ -z "$record" ] || [ -z "$checksum" ] || [ "${4:-}" ]; then
  echo "usage: $0 <release-tag> <release-audit.json> <release-audit.json.sha256>" >&2
  exit 2
fi

command -v gh >/dev/null 2>&1 || { echo "gh is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
command -v cosign >/dev/null 2>&1 || { echo "cosign is required" >&2; exit 2; }
command -v cmp >/dev/null 2>&1 || { echo "cmp is required" >&2; exit 2; }

test -s "$record" || { echo "missing or empty audit record: $record" >&2; exit 1; }
test -s "$checksum" || { echo "missing or empty audit checksum: $checksum" >&2; exit 1; }
[ "$(basename -- "$record")" = release-audit.json ] || { echo "audit record must be named release-audit.json" >&2; exit 1; }
[ "$(basename -- "$checksum")" = release-audit.json.sha256 ] || { echo "audit checksum must be named release-audit.json.sha256" >&2; exit 1; }

record_dir=$(CDPATH= cd -- "$(dirname -- "$record")" && pwd)
checksum_dir=$(CDPATH= cd -- "$(dirname -- "$checksum")" && pwd)
[ "$record_dir" = "$checksum_dir" ] || { echo "audit record and checksum must share a directory" >&2; exit 1; }
bundle="$record_dir/release-audit.bundle.json"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=${GITHUB_REPOSITORY:-Ploos-AS/gamja}
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM

release_json="$workdir/release.json"
gh release view "$tag" --repo "$repo" --json tagName,isDraft,assets > "$release_json"

jq -e --arg tag "$tag" '.tagName == $tag and .isDraft == false' "$release_json" >/dev/null || {
  echo "release metadata does not match expected published tag $tag" >&2
  exit 1
}

base_set='["release-evidence.bundle.json","release-evidence.json","release-evidence.json.sha256"]'
full_set='["release-audit.bundle.json","release-audit.json","release-audit.json.sha256","release-evidence.bundle.json","release-evidence.json","release-evidence.json.sha256"]'
asset_names=$(jq -c '[.assets[].name] | sort' "$release_json")
all_nonempty=$(jq -r 'all(.assets[]; (.size // 0) > 0)' "$release_json")
[ "$all_nonempty" = true ] || { echo "release contains an empty asset" >&2; exit 1; }

if [ "$asset_names" = "$base_set" ]; then
  cosign sign-blob --yes \
    --bundle "$bundle" \
    "$record" >/dev/null
  test -s "$bundle"
  "$script_dir/verify-audit-record.sh" "$record" "$checksum" "$bundle"

  gh release upload "$tag" --repo "$repo" "$record" "$checksum" "$bundle"
  state=published
elif [ "$asset_names" = "$full_set" ]; then
  state=reused
else
  echo "release asset set is neither the M1.20 evidence set nor the exact M1.24 durable audit set" >&2
  exit 1
fi

# Re-read the release after a possible first publication. From this point onward,
# M1.24 requires the exact durable six-asset set and refuses partial/extra state.
gh release view "$tag" --repo "$repo" --json tagName,isDraft,assets > "$release_json"
jq -e --arg tag "$tag" '
  .tagName == $tag and .isDraft == false and
  ([.assets[].name] | sort) == [
    "release-audit.bundle.json",
    "release-audit.json",
    "release-audit.json.sha256",
    "release-evidence.bundle.json",
    "release-evidence.json",
    "release-evidence.json.sha256"
  ] and
  all(.assets[]; (.size // 0) > 0)
' "$release_json" >/dev/null || {
  echo "release does not contain the exact non-empty M1.24 durable audit set" >&2
  exit 1
}

archive_dir="$workdir/archive"
mkdir -p "$archive_dir"
gh release download "$tag" \
  --repo "$repo" \
  --pattern 'release-audit.json' \
  --pattern 'release-audit.json.sha256' \
  --pattern 'release-audit.bundle.json' \
  --dir "$archive_dir"

for asset in release-audit.json release-audit.json.sha256 release-audit.bundle.json; do
  test -s "$archive_dir/$asset" || { echo "missing or empty durable audit asset: $asset" >&2; exit 1; }
done

# The deterministic M1.21 record and checksum must still be byte-identical to a
# freshly recomputed full audit. The signature bundle is intentionally reused.
cmp "$record" "$archive_dir/release-audit.json"
cmp "$checksum" "$archive_dir/release-audit.json.sha256"
"$script_dir/verify-audit-record.sh" \
  "$archive_dir/release-audit.json" \
  "$archive_dir/release-audit.json.sha256" \
  "$archive_dir/release-audit.bundle.json"

# Keep the durable bundle beside the fresh deterministic pair so the secondary
# Actions artifact contains exactly the same signed triplet as the Release.
cp "$archive_dir/release-audit.bundle.json" "$bundle"

printf 'M1.24 durable audit retention verified: tag=%s state=%s\n' "$tag" "$state"
