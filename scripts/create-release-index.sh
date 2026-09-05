#!/bin/sh
set -eu

root=${1:-}
out=${2:-}
if [ -z "$root" ] || [ -z "$out" ]; then
  echo "usage: $0 <release-assets-root> <output.json>" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }
[ -d "$root" ] || { echo "release-assets-root is not a directory: $root" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
entries="$work/entries.jsonl"
: > "$entries"

find "$root" -mindepth 2 -maxdepth 2 -type f -name release-evidence.json -print | LC_ALL=C sort | while IFS= read -r evidence; do
  dir=$(dirname "$evidence")
  tag=$(basename "$dir")
  audit="$dir/release-audit.json"
  evidence_sum="$dir/release-evidence.json.sha256"
  evidence_bundle="$dir/release-evidence.bundle.json"
  audit_sum="$dir/release-audit.json.sha256"
  audit_bundle="$dir/release-audit.bundle.json"

  for required in "$audit" "$evidence_sum" "$evidence_bundle" "$audit_sum" "$audit_bundle"; do
    [ -f "$required" ] || { echo "incomplete M1.24 release asset set for $tag: missing $(basename "$required")" >&2; exit 1; }
  done

  actual_names=$(find "$dir" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)
  expected_names=$(printf '%s\n' \
    release-audit.bundle.json \
    release-audit.json \
    release-audit.json.sha256 \
    release-evidence.bundle.json \
    release-evidence.json \
    release-evidence.json.sha256 | LC_ALL=C sort)
  [ "$actual_names" = "$expected_names" ] || { echo "unexpected release asset set for $tag" >&2; exit 1; }

  (cd "$dir" && sha256sum -c release-evidence.json.sha256 >/dev/null)
  (cd "$dir" && sha256sum -c release-audit.json.sha256 >/dev/null)

  evidence_tag=$(jq -er '.tag' "$evidence")
  evidence_commit=$(jq -er '.release_commit' "$evidence")
  evidence_image=$(jq -er '.image' "$evidence")
  evidence_digest=$(jq -er '.digest' "$evidence")
  audit_tag=$(jq -er '.release.tag' "$audit")
  audit_commit=$(jq -er '.release.commit' "$audit")
  audit_image=$(jq -er '.image.name' "$audit")
  audit_digest=$(jq -er '.image.digest' "$audit")

  [ "$tag" = "$evidence_tag" ] || { echo "directory tag does not match evidence tag: $tag" >&2; exit 1; }
  [ "$evidence_tag" = "$audit_tag" ] || { echo "evidence/audit tag mismatch for $tag" >&2; exit 1; }
  [ "$evidence_commit" = "$audit_commit" ] || { echo "evidence/audit commit mismatch for $tag" >&2; exit 1; }
  [ "$evidence_image" = "$audit_image" ] || { echo "evidence/audit image mismatch for $tag" >&2; exit 1; }
  [ "$evidence_digest" = "$audit_digest" ] || { echo "evidence/audit digest mismatch for $tag" >&2; exit 1; }

  printf '%s' "$evidence_commit" | grep -Eq '^[0-9a-f]{40}$' || { echo "invalid release commit for $tag" >&2; exit 1; }
  printf '%s' "$evidence_digest" | grep -Eq '^sha256:[0-9a-f]{64}$' || { echo "invalid image digest for $tag" >&2; exit 1; }

  evidence_sha=$(sha256sum "$evidence" | awk '{print $1}')
  evidence_sum_sha=$(sha256sum "$evidence_sum" | awk '{print $1}')
  evidence_bundle_sha=$(sha256sum "$evidence_bundle" | awk '{print $1}')
  audit_sha=$(sha256sum "$audit" | awk '{print $1}')
  audit_sum_sha=$(sha256sum "$audit_sum" | awk '{print $1}')
  audit_bundle_sha=$(sha256sum "$audit_bundle" | awk '{print $1}')

  jq -cn \
    --arg tag "$tag" \
    --arg commit "$evidence_commit" \
    --arg image "$evidence_image" \
    --arg digest "$evidence_digest" \
    --arg evidence_sha "$evidence_sha" \
    --arg evidence_sum_sha "$evidence_sum_sha" \
    --arg evidence_bundle_sha "$evidence_bundle_sha" \
    --arg audit_sha "$audit_sha" \
    --arg audit_sum_sha "$audit_sum_sha" \
    --arg audit_bundle_sha "$audit_bundle_sha" \
    '{
      tag: $tag,
      release_commit: $commit,
      image: $image,
      digest: $digest,
      evidence: {
        json: {name: "release-evidence.json", sha256: $evidence_sha},
        checksum: {name: "release-evidence.json.sha256", sha256: $evidence_sum_sha},
        bundle: {name: "release-evidence.bundle.json", sha256: $evidence_bundle_sha}
      },
      audit: {
        json: {name: "release-audit.json", sha256: $audit_sha},
        checksum: {name: "release-audit.json.sha256", sha256: $audit_sum_sha},
        bundle: {name: "release-audit.bundle.json", sha256: $audit_bundle_sha}
      }
    }' >> "$entries"
done

jq -s 'sort_by(.tag) as $releases |
  if (($releases | map(.tag) | unique | length) != ($releases | length)) then error("duplicate release tag") else . end |
  {
    schema: "https://github.com/Ploos-AS/gamja/releases/transparency-index/v1",
    milestone: "M1.25",
    ordering: "bytewise-tag-ascending",
    releases: $releases
  }' "$entries" > "$out"

jq -e '.milestone == "M1.25" and .ordering == "bytewise-tag-ascending" and (.releases | type == "array")' "$out" >/dev/null
