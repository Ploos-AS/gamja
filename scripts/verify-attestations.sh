#!/bin/sh
set -eu

image=${1:-}
if [ -z "$image" ]; then
  echo "usage: $0 <image-ref-or-digest>" >&2
  exit 2
fi

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

echo "Verifying BuildKit attestations for $image"

for platform in linux/amd64 linux/arm64; do
  sbom_file=$(mktemp)
  provenance_file=$(mktemp)
  trap 'rm -f "$sbom_file" "$provenance_file"' EXIT HUP INT TERM

  docker buildx imagetools inspect "$image" \
    --format "{{ json (index .SBOM \"$platform\").SPDX }}" >"$sbom_file"
  jq -e '
    type == "object" and
    .SPDXID == "SPDXRef-DOCUMENT" and
    (.spdxVersion | type == "string") and
    (.packages | type == "array")
  ' "$sbom_file" >/dev/null

  docker buildx imagetools inspect "$image" \
    --format "{{ json (index .Provenance \"$platform\").SLSA }}" >"$provenance_file"
  jq -e '
    type == "object" and
    .buildType == "https://mobyproject.org/buildkit@v1" and
    (.invocation | type == "object") and
    (.metadata | type == "object") and
    (.materials | type == "array")
  ' "$provenance_file" >/dev/null

  echo "$platform: SPDX SBOM + BuildKit SLSA provenance verified"
  rm -f "$sbom_file" "$provenance_file"
  trap - EXIT HUP INT TERM
done
