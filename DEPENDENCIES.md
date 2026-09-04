# Dependency policy

M1.10 adds continuous qualification for the external dependencies required to build, publish and operate the Gamja container.

## Policy

Production and CI dependencies stay pinned to immutable digests or commit SHAs where the ecosystem supports it. Mutable tags may be inspected for drift, but drift never changes a production pin automatically.

Qualification covers:

- builder image `node:22.23.2-alpine3.24` at its pinned multi-platform digest;
- runtime image `nginxinc/nginx-unprivileged:1.30-alpine3.24` at its pinned multi-platform digest;
- production Soju image at its pinned multi-platform digest;
- production Caddy image at its pinned multi-platform digest;
- BuildKit at its pinned digest;
- GitHub Actions used by the container/security workflows at immutable commit SHAs.

The dedicated `dependencies` workflow runs on pushes, pull requests, manual dispatch and daily. It fails if an immutable production pin can no longer be fetched or if a required pinned GitHub Action commit can no longer be resolved.

Mutable tag drift is reported as either `current` or `update-available`. An update-available result is informational. Adoption requires an explicit repository change followed by the full qualification suite.

## Update procedure

For an intentional dependency refresh:

1. Resolve the desired tag to its multi-platform OCI index digest or GitHub Action commit SHA.
2. Review upstream release notes and security impact.
3. Replace the exact pin in the repository.
4. Update this document when the dependency family or policy changes.
5. Require the complete container, security, production Compose, Quadlet, operations, release-integrity, upstream and dependency qualification suite to pass before release.

This deliberately separates automated discovery from human-controlled adoption.
