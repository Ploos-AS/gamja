# Upstream source policy

This repository packages Gamja from `Libera-Chat/gamja`. The production image is intentionally built from an immutable upstream commit rather than from a moving branch or tag.

## Current pin

- upstream repository: `Libera-Chat/gamja`
- tracked upstream branch: `production`
- pinned commit: `0f273b96994fb32b3a1b868d4b59229285f3455c`

The Dockerfile is the authoritative production pin.

## M1.9 drift qualification

The `upstream` GitHub Actions workflow runs on pushes, pull requests, manual dispatch and once per day. It verifies that the pinned commit still exists upstream and compares it with the current head of upstream `production`.

A changed upstream head is informational: CI reports `update-available` but does not fail merely because upstream moved. Network/API failures, malformed responses, or an invalid local pin do fail qualification because they prevent trustworthy comparison.

The workflow also exercises both checker states (`current` and `update-available`) with deterministic local fixtures so drift semantics do not depend solely on the live GitHub API.

## Update procedure

Never update the production pin automatically. For an intentional upstream refresh:

1. Review the upstream commit range and upstream release/security context.
2. Change `GAMJA_COMMIT` in `Dockerfile` to the exact reviewed 40-character commit SHA.
3. Update the current pin documented here and in `README.md`.
4. Let all existing runtime, WebSocket, reverse-proxy, production Compose, Quadlet, security and release-integrity qualification run against the new source.
5. Only tag a release after the complete qualification set is green.

This keeps upstream discovery automated while source adoption remains an explicit, reviewable repository change.
