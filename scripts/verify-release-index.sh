#!/bin/sh
set -eu

index=${1:-}
root=${2:-}
if [ -z "$index" ]; then
  echo "usage: $0 <release-index.json> [release-assets-root]" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }
[ -f "$index" ] || { echo "index not found: $index" >&2; exit 2; }

jq -e '
  (keys == ["milestone","ordering","releases","schema"]) and
  .schema == "https://github.com/Ploos-AS/gamja/releases/transparency-index/v1" and
  .milestone == "M1.25" and
  .ordering == "bytewise-tag-ascending" and
  (.releases | type == "array") and
  ((.releases | map(.tag)) == (.releases | map(.tag) | sort)) and
  ((.releases | map(.tag) | unique | length) == (.releases | length)) and
  all(.releases[];
    (keys == ["audit","digest","evidence","image","release_commit","tag"]) and
    (.tag | test("^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$")) and
    (.release_commit | test("^[0-9a-f]{40}$")) and
    (.image | type == "string" and length > 0) and
    (.digest | test("^sha256:[0-9a-f]{64}$")) and
    (.evidence | keys == ["bundle","checksum","json"]) and
    (.audit | keys == ["bundle","checksum","json"]) and
    (.evidence.json | keys == ["name","sha256"]) and
    (.evidence.checksum | keys == ["name","sha256"]) and
    (.evidence.bundle | keys == ["name","sha256"]) and
    (.audit.json | keys == ["name","sha256"]) and
    (.audit.checksum | keys == ["name","sha256"]) and
    (.audit.bundle | keys == ["name","sha256"]) and
    .evidence.json.name == "release-evidence.json" and
    .evidence.checksum.name == "release-evidence.json.sha256" and
    .evidence.bundle.name == "release-evidence.bundle.json" and
    .audit.json.name == "release-audit.json" and
    .audit.checksum.name == "release-audit.json.sha256" and
    .audit.bundle.name == "release-audit.bundle.json" and
    all([
      .evidence.json.sha256,
      .evidence.checksum.sha256,
      .evidence.bundle.sha256,
      .audit.json.sha256,
      .audit.checksum.sha256,
      .audit.bundle.sha256
    ][]; test("^[0-9a-f]{64}$"))
  )
' "$index" >/dev/null

if [ -n "$root" ]; then
  [ -d "$root" ] || { echo "release-assets-root is not a directory: $root" >&2; exit 2; }

  jq -c '.releases[]' "$index" | while IFS= read -r entry; do
    tag=$(jq -r '.tag' <<EOF
$entry
EOF
)
    dir="$root/$tag"
    [ -d "$dir" ] || { echo "indexed release directory missing: $tag" >&2; exit 1; }

    actual_names=$(find "$dir" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)
    expected_names=$(printf '%s\n' \
      release-audit.bundle.json \
      release-audit.json \
      release-audit.json.sha256 \
      release-evidence.bundle.json \
      release-evidence.json \
      release-evidence.json.sha256 | LC_ALL=C sort)
    [ "$actual_names" = "$expected_names" ] || { echo "asset set drift for $tag" >&2; exit 1; }

    for pair in \
      'evidence.json release-evidence.json' \
      'evidence.checksum release-evidence.json.sha256' \
      'evidence.bundle release-evidence.bundle.json' \
      'audit.json release-audit.json' \
      'audit.checksum release-audit.json.sha256' \
      'audit.bundle release-audit.bundle.json'; do
      key=${pair%% *}
      name=${pair#* }
      expected=$(jq -r ".$key.sha256" <<EOF
$entry
EOF
)
      actual=$(sha256sum "$dir/$name" | awk '{print $1}')
      [ "$actual" = "$expected" ] || { echo "indexed asset hash mismatch for $tag/$name" >&2; exit 1; }
    done

    evidence="$dir/release-evidence.json"
    audit="$dir/release-audit.json"
    [ "$(jq -r '.tag' "$evidence")" = "$tag" ] || { echo "evidence tag mismatch for $tag" >&2; exit 1; }
    [ "$(jq -r '.release.tag' "$audit")" = "$tag" ] || { echo "audit tag mismatch for $tag" >&2; exit 1; }
    [ "$(jq -r '.release_commit' "$evidence")" = "$(jq -r '.release.commit' "$audit")" ] || { echo "commit binding mismatch for $tag" >&2; exit 1; }
    [ "$(jq -r '.image' "$evidence")" = "$(jq -r '.image.name' "$audit")" ] || { echo "image binding mismatch for $tag" >&2; exit 1; }
    [ "$(jq -r '.digest' "$evidence")" = "$(jq -r '.image.digest' "$audit")" ] || { echo "digest binding mismatch for $tag" >&2; exit 1; }
  done
fi

echo "M1.25 release transparency index verified"
