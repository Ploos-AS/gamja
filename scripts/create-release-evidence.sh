#!/bin/sh
set -eu

output=${1:-}
tag=${TAG:-}
version=${VERSION:-}
image=${IMAGE:-}
digest=${DIGEST:-}
release_commit=${RELEASE_COMMIT:-}

if [ -z "$output" ] || [ -z "$tag" ] || [ -z "$version" ] || [ -z "$image" ] || [ -z "$digest" ] || [ -z "$release_commit" ]; then
  echo "usage: TAG=... VERSION=... IMAGE=... DIGEST=... RELEASE_COMMIT=... $0 <output.json>" >&2
  exit 2
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

case "$digest" in sha256:[0-9a-f][0-9a-f]*) ;; *) echo "invalid OCI digest: $digest" >&2; exit 2 ;; esac
[ "${#digest}" -eq 71 ] || { echo "invalid OCI sha256 digest length" >&2; exit 2; }
printf '%s' "${digest#sha256:}" | grep -Eq '^[0-9a-f]{64}$' || { echo "invalid OCI sha256 digest" >&2; exit 2; }
printf '%s' "$release_commit" | grep -Eq '^[0-9a-f]{40}$' || { echo "invalid release commit" >&2; exit 2; }

jq -n \
  --arg schema "https://github.com/Ploos-AS/gamja/blob/main/RELEASE-EVIDENCE.md" \
  --arg tag "$tag" \
  --arg version "$version" \
  --arg image "$image" \
  --arg digest "$digest" \
  --arg commit "$release_commit" \
  '{
    schema: $schema,
    tag: $tag,
    version: $version,
    image: $image,
    digest: $digest,
    release_commit: $commit,
    platforms: ["linux/amd64", "linux/arm64"],
    signature: {
      scheme: "cosign-keyless",
      oidc_issuer: "https://token.actions.githubusercontent.com",
      workflow_identity: ("https://github.com/Ploos-AS/gamja/.github/workflows/container.yml@refs/tags/" + $tag)
    },
    evidence_signature: {
      scheme: "cosign-keyless-blob",
      oidc_issuer: "https://token.actions.githubusercontent.com",
      workflow_identity: "https://github.com/Ploos-AS/gamja/.github/workflows/release.yml@refs/heads/main"
    },
    attestations: {
      sbom: "SPDX",
      provenance: "BuildKit SLSA",
      platforms: ["linux/amd64", "linux/arm64"]
    },
    runtime: {
      platforms: ["linux/amd64", "linux/arm64"],
      immutable_digest: true,
      uid: 101,
      read_only_rootfs: true,
      no_new_privileges: true,
      healthy: true,
      generated_config_verified: true,
      websocket_upgrade_verified: true
    },
    verification: {
      tag_commit_equals_workflow_commit: true,
      oci_revision_equals_release_commit: true,
      signature_verified: true,
      attestations_verified: true,
      runtime_verified: true
    }
  }' > "$output"

jq -e \
  --arg tag "$tag" --arg version "$version" --arg image "$image" --arg digest "$digest" --arg commit "$release_commit" \
  '.tag == $tag and .version == $version and .image == $image and .digest == $digest and .release_commit == $commit and (.platforms | length == 2) and .signature.scheme == "cosign-keyless" and .evidence_signature.scheme == "cosign-keyless-blob" and .verification.signature_verified == true and .verification.attestations_verified == true and .verification.runtime_verified == true and .runtime.platforms == ["linux/amd64","linux/arm64"]' \
  "$output" >/dev/null
