# Image signing policy

M1.11 adds keyless Cosign signing for every published Gamja OCI image.

## Trust model

The container workflow already receives a short-lived GitHub Actions OIDC identity for BuildKit provenance. After the multi-architecture OCI index is pushed, the same workflow signs the exact immutable digest with Cosign keyless signing. No long-lived signing key or repository signing secret is stored.

The expected signer is the repository workflow identity:

```text
https://github.com/Ploos-AS/gamja/.github/workflows/container.yml@refs/heads/main
```

Release tags use the corresponding `refs/tags/v...` identity. The expected OIDC issuer is:

```text
https://token.actions.githubusercontent.com
```

The workflow immediately verifies the signature against that issuer and repository/workflow identity. A signing or verification failure fails publication qualification.

## Verify a published image

Install Cosign, resolve the image to the digest you intend to trust, then verify the digest rather than relying only on a mutable tag:

```sh
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/Ploos-AS/gamja/.github/workflows/container.yml@refs/(heads/main|tags/v.*)$' \
  ghcr.io/ploos-as/gamja@sha256:<digest>
```

Verification proves that the digest was signed by the expected GitHub Actions workflow identity. It does not replace vulnerability scanning, provenance review, release-integrity checks, or runtime qualification; those remain separate gates.

## Release policy

A release is only considered qualified when the container workflow has successfully built, scanned, pushed, signed and verified the exact OCI digest. The existing release-integrity gate independently binds the release tag, workflow commit and OCI revision annotation.

Cosign installer is itself pinned to an immutable commit SHA and is covered by the M1.10 dependency qualification workflow.
