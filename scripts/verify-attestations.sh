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

  echo "Checking $platform SPDX SBOM"
  if ! docker buildx imagetools inspect "$image" \
    --format "{{ json (index .SBOM \"$platform\").SPDX }}" >"$sbom_file"; then
    echo "$platform: failed to retrieve SPDX SBOM attestation" >&2
    exit 1
  fi
  if ! jq -e '
    type == "object" and
    .SPDXID == "SPDXRef-DOCUMENT" and
    (.spdxVersion | type == "string")
  ' "$sbom_file" >/dev/null; then
    echo "$platform: invalid SPDX SBOM attestation" >&2
    echo "Decoded SBOM:" >&2
    cat "$sbom_file" >&2
    exit 1
  fi

  echo "Checking $platform BuildKit SLSA provenance"
  if ! docker buildx imagetools inspect "$image" \
    --format "{{ json (index .Provenance \"$platform\").SLSA }}" >"$provenance_file"; then
    echo "$platform: failed to retrieve BuildKit provenance attestation" >&2
    exit 1
  fi
  if ! jq -e '
    type == "object" and
    .buildDefinition.buildType == "https://github.com/moby/buildkit/blob/master/docs/attestations/slsa-definitions.md" and
    (.buildDefinition.externalParameters | type == "object") and
    (.buildDefinition.resolvedDependencies | type == "array") and
    (.runDetails.builder.id | type == "string") and
    (.runDetails.metadata | type == "object")
  ' "$provenance_file" >/dev/null; then
    echo "$platform: invalid BuildKit SLSA provenance attestation" >&2
    echo "Decoded provenance:" >&2
    cat "$provenance_file" >&2
    exit 1
  fi

  echo "$platform: SPDX SBOM + BuildKit SLSA provenance verified"
  rm -f "$sbom_file" "$provenance_file"
  trap - EXIT HUP INT TERM
done
