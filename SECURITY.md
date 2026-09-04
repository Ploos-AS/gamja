# Security policy

This repository packages a pinned upstream Gamja revision into an OCI image. Security qualification therefore covers both the resulting runtime image and the deployment/configuration files maintained here.

## Automated qualification

M1.7 adds two complementary security gates:

- runtime image scanning for fixable `HIGH` and `CRITICAL` OS/library vulnerabilities;
- repository scanning for `HIGH` and `CRITICAL` secret and misconfiguration findings.

The scans use Trivy `v0.74.0`. The GitHub Action is pinned to the immutable commit for `aquasecurity/trivy-action` v0.36.0.

Unfixed vulnerabilities are reported by the ecosystem but do not block this repository until the distribution/vendor publishes a fix. Once a fix exists, a `HIGH` or `CRITICAL` finding blocks qualification and image publication until it is remediated or explicitly reviewed.

No `.trivyignore` baseline is maintained by default. A future suppression must be narrow, documented, time-bounded where practical, and tied to a concrete false-positive or accepted-risk rationale.

## Continuous re-scan

The dedicated `security` workflow runs on pushes, pull requests, manual dispatch, and once per day. This intentionally re-evaluates the current source and runtime image against newer vulnerability intelligence even when the repository itself has not changed.

## Release policy

The release/container workflow also executes the runtime and repository security gates before authenticating to GHCR and before publishing the multi-architecture image. A failing security gate therefore prevents publication of `latest` and version tags.

## Scope boundary

Gamja is a browser application. Values emitted into its generated `/config.json`, including OAuth client data, are visible to the browser and must not be treated as server-side secrets.

The build stage contains Node.js and upstream build dependencies, but the final runtime image does not. The release-blocking image scan targets the shipped runtime image; repository secret/misconfiguration scanning separately covers files maintained by this packaging repository.
