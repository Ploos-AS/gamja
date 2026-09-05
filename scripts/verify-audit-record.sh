#!/bin/sh
set -eu

record=${1:-}
checksum=${2:-}
if [ -z "$record" ] || [ -z "$checksum" ] || [ "${3:-}" ]; then
  echo "usage: $0 <release-audit.json> <release-audit.json.sha256>" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }
test -s "$record" || { echo "missing or empty audit record: $record" >&2; exit 1; }
test -s "$checksum" || { echo "missing or empty audit checksum: $checksum" >&2; exit 1; }

record_dir=$(CDPATH= cd -- "$(dirname -- "$record")" && pwd)
record_base=$(basename -- "$record")
checksum_dir=$(CDPATH= cd -- "$(dirname -- "$checksum")" && pwd)
checksum_base=$(basename -- "$checksum")
[ "$record_dir" = "$checksum_dir" ] || { echo "audit record and checksum must be in the same directory" >&2; exit 1; }

checksum_line=$(cat "$checksum")
printf '%s\n' "$checksum_line" | grep -Eq '^[0-9a-f]{64}  release-audit\.json$' || {
  echo "invalid audit checksum format" >&2
  exit 1
}
[ "$record_base" = release-audit.json ] || { echo "audit record must be named release-audit.json" >&2; exit 1; }
[ "$checksum_base" = release-audit.json.sha256 ] || { echo "audit checksum must be named release-audit.json.sha256" >&2; exit 1; }
(cd "$record_dir" && sha256sum -c "$checksum_base" >/dev/null)

jq -e '
  (keys | sort) == ["image","milestone","release","schema","verification","verifier"] and
  .schema == "https://github.com/Ploos-AS/gamja/releases/audit-record/v1" and
  .milestone == "M1.21" and
  (.release | keys | sort) == ["commit","tag"] and
  (.release.tag | type == "string" and test("^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$")) and
  (.release.commit | type == "string" and test("^[0-9a-f]{40}$")) and
  (.image | keys | sort) == ["digest","immutable","name"] and
  (.image.name | type == "string" and length > 0) and
  (.image.digest | type == "string" and test("^sha256:[0-9a-f]{64}$")) and
  .image.immutable == true and
  (.verification | keys | sort) == [
    "evidence_checksum",
    "evidence_keyless_signature",
    "exact_release_asset_set",
    "github_release_non_draft",
    "image_keyless_signature",
    "oci_revision_matches_release_commit",
    "provenance_amd64",
    "provenance_arm64",
    "runtime_amd64",
    "runtime_arm64",
    "sbom_amd64",
    "sbom_arm64",
    "tag_commit_matches_evidence"
  ] and
  (.verification | to_entries | all(.value == true)) and
  .verifier == {
    audit: "scripts/audit-release.sh",
    consumer: "scripts/verify-release.sh",
    attestations: "scripts/verify-attestations.sh"
  }
' "$record" >/dev/null || {
  echo "audit record does not satisfy the canonical M1.22 consumer contract" >&2
  exit 1
}

printf 'M1.22 audit record verification passed: tag=%s commit=%s digest=%s\n' \
  "$(jq -r '.release.tag' "$record")" \
  "$(jq -r '.release.commit' "$record")" \
  "$(jq -r '.image.digest' "$record")"
