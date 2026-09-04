# syntax=docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e
ARG GAMJA_REPO=https://github.com/Libera-Chat/gamja.git
ARG GAMJA_COMMIT=0f273b96994fb32b3a1b868d4b59229285f3455c

# Multi-platform index digest for node:22.23.2-alpine3.24.
FROM node:22.23.2-alpine3.24@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32 AS builder
ARG GAMJA_REPO
ARG GAMJA_COMMIT
RUN apk add --no-cache git
WORKDIR /src
RUN git clone "${GAMJA_REPO}" . \
 && git checkout --detach "${GAMJA_COMMIT}" \
 && npm ci --include=dev \
 && npm run build

# Multi-platform index digest for nginxinc/nginx-unprivileged:1.30-alpine3.24.
FROM nginxinc/nginx-unprivileged:1.30-alpine3.24@sha256:9b87ad3dd9f431c733f19dfb278c7eb3dba9dca381942c79818bb42f1a566a83
LABEL org.opencontainers.image.title="Gamja" \
      org.opencontainers.image.description="Minimal non-root container for the Gamja IRC web client" \
      org.opencontainers.image.source="https://github.com/Ploos-AS/gamja" \
      org.opencontainers.image.licenses="AGPL-3.0-only"
ENV SOJU_HOST=soju \
    SOJU_PORT=8080
COPY nginx.conf /etc/gamja/nginx.conf.template
COPY --chmod=0755 entrypoint.sh /usr/local/bin/gamja-entrypoint
COPY --from=builder /src/dist/ /usr/share/nginx/html/
COPY config.json /usr/share/nginx/html/config.json
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
ENTRYPOINT ["/usr/local/bin/gamja-entrypoint"]
