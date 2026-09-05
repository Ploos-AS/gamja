#!/bin/sh
set -eu

mode=full
if [ "${1:-}" = "--metadata-only" ]; then
  mode=metadata
  shift
fi

tag=${1:-}
if [ -z "$tag" ]; then
  echo "usage: $0 [--metadata-only] <release-tag>" >&2
  exit 2
fi

command -v gh >/dev/null 2>&1 || { echo "gh is required" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$script_dir/validate-release-tag.sh" "$tag" >/dev/null

repo=${GITHUB_REPOSITORY:-Ploos-AS/gamja}
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM

release_json="$workdir/release.json"
gh release view "$tag" --repo "$repo" --json tagName,isDraft,assets > "$release_json"

jq -e --arg tag "$tag" '.tagName == $tag and .isDraft == false' "$release_json" >/dev/null || {
  echo "release metadata does not match expected published tag $tag" >&2
  exit 1
}

jq -e '
  ([.assets[].name] | sort) == [
    "release-evidence.bundle.json",
    "release-evidence.json",
    "release-evidence.json.sha256"
  ] and
  all(.assets[]; (.size // 0) > 0)
' "$release_json" >/dev/null || {
  echo "release asset set is not the exact M1.20 evidence bundle" >&2
  exit 1
}

tag_commit=$(git rev-parse "${tag}^{commit}")
printf '%s' "$tag_commit" | grep -Eq '^[0-9a-f]{40}$' || { echo "invalid resolved release commit" >&2; exit 1; }

asset_dir="$workdir/assets"
mkdir -p "$asset_dir"
gh release download "$tag" \
  --repo "$repo" \
  --pattern 'release-evidence.json' \
  --pattern 'release-evidence.json.sha256' \
  --pattern 'release-evidence.bundle.json' \
  --dir "$asset_dir"

for asset in release-evidence.json release-evidence.json.sha256 release-evidence.bundle.json; do
  test -s "$asset_dir/$asset" || { echo "missing or empty release asset: $asset" >&2; exit 1; }
done

evidence_tag=$(jq -r '.tag // empty' "$asset_dir/release-evidence.json")
evidence_commit=$(jq -r '.release_commit // empty' "$asset_dir/release-evidence.json")
[ "$evidence_tag" = "$tag" ] || { echo "evidence tag mismatch: $evidence_tag" >&2; exit 1; }
[ "$evidence_commit" = "$tag_commit" ] || {
  echo "release tag commit $tag_commit does not match evidence commit $evidence_commit" >&2
  exit 1
}

chmod +x "$script_dir/verify-release.sh" "$script_dir/verify-attestations.sh"
if [ "$mode" = metadata ]; then
  "$script_dir/verify-release.sh" --metadata-only \
    "$asset_dir/release-evidence.json" \
    "$asset_dir/release-evidence.json.sha256"
  echo "M1.20 release metadata audit passed for $tag ($tag_commit)."
  exit 0
fi

"$script_dir/verify-release.sh" \
  "$asset_dir/release-evidence.json" \
  "$asset_dir/release-evidence.json.sha256" \
  "$asset_dir/release-evidence.bundle.json"

echo "M1.20 release audit passed for $tag ($tag_commit)."
