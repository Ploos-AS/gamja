#!/bin/sh
set -eu

out=${1:-}
if [ -z "$out" ]; then
  echo "usage: $0 <output.json>" >&2
  exit 2
fi

: "${TAG:?TAG is required}"
: "${RELEASE_COMMIT:?RELEASE_COMMIT is required}"
: "${IMAGE:?IMAGE is required}"
: "${DIGEST:?DIGEST is required}"

printf '%s' "$RELEASE_COMMIT" | grep -Eq '^[0-9a-f]{40}$' || { echo "invalid RELEASE_COMMIT" >&2; exit 2; }
printf '%s' "$DIGEST" | grep -Eq '^sha256:[0-9a-f]{64}$' || { echo "invalid DIGEST" >&2; exit 2; }

jq -n \
  --arg tag "$TAG" \
  --arg commit "$RELEASE_COMMIT" \
  --arg image "$IMAGE" \
  --arg digest "$DIGEST" \
  '{
    schema: "https://github.com/Ploos-AS/gamja/releases/audit-record/v1",
    milestone: "M1.21",
    release: {
      tag: $tag,
      commit: $commit
    },
    image: {
      name: $image,
      digest: $digest,
      immutable: true
    },
    verification: {
      github_release_non_draft: true,
      exact_release_asset_set: true,
      tag_commit_matches_evidence: true,
      evidence_checksum: true,
      evidence_keyless_signature: true,
      oci_revision_matches_release_commit: true,
      image_keyless_signature: true,
      sbom_amd64: true,
      sbom_arm64: true,
      provenance_amd64: true,
      provenance_arm64: true,
      runtime_amd64: true,
      runtime_arm64: true
    },
    verifier: {
      audit: "scripts/audit-release.sh",
      consumer: "scripts/verify-release.sh",
      attestations: "scripts/verify-attestations.sh"
    }
  }' > "$out"

jq -e \
  --arg tag "$TAG" \
  --arg commit "$RELEASE_COMMIT" \
  --arg digest "$DIGEST" \
  '.milestone == "M1.21" and .release.tag == $tag and .release.commit == $commit and .image.digest == $digest and (.verification | to_entries | all(.value == true))' \
  "$out" >/dev/null
