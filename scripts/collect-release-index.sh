#!/bin/sh
set -eu

out=${1:-}
if [ -z "$out" ]; then
  echo "usage: $0 <output.json>" >&2
  exit 2
fi

: "${GH_TOKEN:?GH_TOKEN is required}"
repo=${GITHUB_REPOSITORY:-Ploos-AS/gamja}

command -v gh >/dev/null 2>&1 || { echo "gh is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
root="$work/releases"
mkdir -p "$root"

expected=$(printf '%s\n' \
  release-audit.bundle.json \
  release-audit.json \
  release-audit.json.sha256 \
  release-evidence.bundle.json \
  release-evidence.json \
  release-evidence.json.sha256 | LC_ALL=C sort)

# GitHub REST pagination avoids an arbitrary release-list limit. Drafts are not transparency entries.
gh api --paginate --slurp "repos/$repo/releases?per_page=100" |
  jq -r '.[][] | select(.draft == false) | .tag_name' |
  LC_ALL=C sort |
  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    metadata=$(gh release view "$tag" --repo "$repo" --json isDraft,assets)
    [ "$(jq -r '.isDraft' <<EOF
$metadata
EOF
)" = false ] || continue

    names=$(jq -r '.assets[].name' <<EOF
$metadata
EOF
)
    relevant=$(printf '%s\n' "$names" | grep -E '^(release-evidence|release-audit)\.(json|bundle\.json)|^(release-evidence|release-audit)\.json\.sha256$' || true)
    [ -n "$relevant" ] || continue

    relevant_sorted=$(printf '%s\n' "$relevant" | LC_ALL=C sort)
    [ "$relevant_sorted" = "$expected" ] || {
      echo "release $tag has a partial or unexpected M1.20-M1.24 transparency asset set" >&2
      exit 1
    }

    dir="$root/$tag"
    mkdir -p "$dir"
    for name in \
      release-evidence.json \
      release-evidence.json.sha256 \
      release-evidence.bundle.json \
      release-audit.json \
      release-audit.json.sha256 \
      release-audit.bundle.json; do
      gh release download "$tag" --repo "$repo" --dir "$dir" --pattern "$name"
    done
  done

sh "$script_dir/create-release-index.sh" "$root" "$out"
sh "$script_dir/verify-release-index.sh" "$out" "$root"
