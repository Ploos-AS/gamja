#!/bin/sh
set -eu

mode=full
if [ "${1:-}" = "--metadata-only" ]; then
  mode=metadata
  shift
fi

evidence=${1:-}
checksum=${2:-}
bundle=${3:-}
if [ -z "$evidence" ] || [ -z "$checksum" ]; then
  echo "usage: $0 [--metadata-only] <release-evidence.json> <release-evidence.json.sha256> [release-evidence.bundle.json]" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }
[ -f "$evidence" ] || { echo "evidence file not found: $evidence" >&2; exit 2; }
[ -f "$checksum" ] || { echo "checksum file not found: $checksum" >&2; exit 2; }

expected_sum=$(awk 'NR == 1 {print $1}' "$checksum")
printf '%s' "$expected_sum" | grep -Eq '^[0-9a-f]{64}$' || { echo "invalid evidence checksum" >&2; exit 1; }
actual_sum=$(sha256sum "$evidence" | awk '{print $1}')
[ "$actual_sum" = "$expected_sum" ] || { echo "release evidence checksum mismatch" >&2; exit 1; }

schema=$(jq -r '.schema // empty' "$evidence")
tag=$(jq -r '.tag // empty' "$evidence")
version=$(jq -r '.version // empty' "$evidence")
image=$(jq -r '.image // empty' "$evidence")
digest=$(jq -r '.digest // empty' "$evidence")
release_commit=$(jq -r '.release_commit // empty' "$evidence")
identity=$(jq -r '.signature.workflow_identity // empty' "$evidence")
issuer=$(jq -r '.signature.oidc_issuer // empty' "$evidence")
evidence_identity=$(jq -r '.evidence_signature.workflow_identity // empty' "$evidence")
evidence_issuer=$(jq -r '.evidence_signature.oidc_issuer // empty' "$evidence")

[ "$schema" = "https://github.com/Ploos-AS/gamja/blob/main/RELEASE-EVIDENCE.md" ] || { echo "unexpected evidence schema: $schema" >&2; exit 1; }
printf '%s' "$tag" | grep -Eq '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$' || { echo "invalid release tag in evidence: $tag" >&2; exit 1; }
[ "$version" = "${tag#v}" ] || { echo "version does not match release tag" >&2; exit 1; }
[ "$image" = "ghcr.io/ploos-as/gamja:$version" ] || { echo "unexpected release image: $image" >&2; exit 1; }
printf '%s' "$digest" | grep -Eq '^sha256:[0-9a-f]{64}$' || { echo "invalid OCI digest in evidence" >&2; exit 1; }
printf '%s' "$release_commit" | grep -Eq '^[0-9a-f]{40}$' || { echo "invalid release commit in evidence" >&2; exit 1; }
[ "$issuer" = "https://token.actions.githubusercontent.com" ] || { echo "unexpected OIDC issuer" >&2; exit 1; }
expected_identity="https://github.com/Ploos-AS/gamja/.github/workflows/container.yml@refs/tags/$tag"
[ "$identity" = "$expected_identity" ] || { echo "unexpected workflow identity: $identity" >&2; exit 1; }
[ "$evidence_issuer" = "https://token.actions.githubusercontent.com" ] || { echo "unexpected evidence OIDC issuer" >&2; exit 1; }
expected_evidence_identity="https://github.com/Ploos-AS/gamja/.github/workflows/release.yml@refs/heads/main"
[ "$evidence_identity" = "$expected_evidence_identity" ] || { echo "unexpected evidence workflow identity: $evidence_identity" >&2; exit 1; }

jq -e '
  .platforms == ["linux/amd64", "linux/arm64"] and
  .signature.scheme == "cosign-keyless" and
  .evidence_signature.scheme == "cosign-keyless-blob" and
  .attestations.sbom == "SPDX" and
  .attestations.provenance == "BuildKit SLSA" and
  .attestations.platforms == ["linux/amd64", "linux/arm64"] and
  .runtime.platforms == ["linux/amd64", "linux/arm64"] and
  .runtime.immutable_digest == true and
  .runtime.uid == 101 and
  .runtime.read_only_rootfs == true and
  .runtime.no_new_privileges == true and
  .runtime.healthy == true and
  .runtime.generated_config_verified == true and
  .runtime.websocket_upgrade_verified == true and
  .verification.tag_commit_equals_workflow_commit == true and
  .verification.oci_revision_equals_release_commit == true and
  .verification.signature_verified == true and
  .verification.attestations_verified == true and
  .verification.runtime_verified == true
' "$evidence" >/dev/null || { echo "release evidence policy fields are invalid" >&2; exit 1; }

echo "Release evidence metadata verified for $tag ($digest)"

if [ "$mode" = metadata ]; then
  exit 0
fi

[ -n "$bundle" ] || { echo "signed evidence bundle is required for full verification" >&2; exit 2; }
[ -f "$bundle" ] || { echo "evidence signature bundle not found: $bundle" >&2; exit 2; }
command -v cosign >/dev/null 2>&1 || { echo "cosign is required for full verification" >&2; exit 2; }
command -v docker >/dev/null 2>&1 || { echo "docker with buildx is required for full verification" >&2; exit 2; }

cosign verify-blob \
  --bundle "$bundle" \
  --certificate-oidc-issuer "$evidence_issuer" \
  --certificate-identity "$evidence_identity" \
  "$evidence" >/dev/null

echo "M1.19 keyless release evidence signature verified."

repo=ghcr.io/ploos-as/gamja
immutable_ref="$repo@$digest"

manifest_file=$(mktemp)
cosign_file=$(mktemp)
trap 'rm -f "$manifest_file" "$cosign_file"' EXIT HUP INT TERM

docker buildx imagetools inspect "$immutable_ref" --raw > "$manifest_file"
oci_revision=$(jq -r '.annotations["org.opencontainers.image.revision"] // empty' "$manifest_file")
[ "$oci_revision" = "$release_commit" ] || {
  echo "OCI revision '$oci_revision' does not match release commit '$release_commit'" >&2
  exit 1
}
jq -e 'any(.manifests[]; .platform.os == "linux" and .platform.architecture == "amd64") and any(.manifests[]; .platform.os == "linux" and .platform.architecture == "arm64")' "$manifest_file" >/dev/null || {
  echo "release OCI index does not contain both required platforms" >&2
  exit 1
}

cosign verify \
  --certificate-oidc-issuer "$issuer" \
  --certificate-identity "$identity" \
  "$immutable_ref" > "$cosign_file"
jq -e 'length > 0' "$cosign_file" >/dev/null || { echo "Cosign signature verification returned no signatures" >&2; exit 1; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$script_dir/verify-attestations.sh" "$immutable_ref"

echo "Release $tag fully verified: signed evidence, checksum, identity, OCI revision, image signature, SPDX SBOM, BuildKit SLSA provenance, and recorded amd64/arm64 runtime qualification."
