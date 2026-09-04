# syntax=docker/dockerfile:1.7
ARG GAMJA_REPO=https://github.com/Libera-Chat/gamja.git
ARG GAMJA_COMMIT=0f273b96994fb32b3a1b868d4b59229285f3455c

FROM node:22-alpine AS builder
ARG GAMJA_REPO
ARG GAMJA_COMMIT
RUN apk add --no-cache git
WORKDIR /src
RUN git clone "${GAMJA_REPO}" . \
 && git checkout --detach "${GAMJA_COMMIT}" \
 && npm ci --include=dev \
 && npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine
LABEL org.opencontainers.image.title="Gamja" \
      org.opencontainers.image.description="Minimal non-root container for the Gamja IRC web client" \
      org.opencontainers.image.source="https://github.com/Ploos-AS/gamja" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later"
ENV SOJU_HOST=soju \
    SOJU_PORT=8080
COPY nginx.conf /etc/gamja/nginx.conf.template
COPY entrypoint.sh /usr/local/bin/gamja-entrypoint
COPY --from=builder /src/dist/ /usr/share/nginx/html/
COPY config.json /usr/share/nginx/html/config.json
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
ENTRYPOINT ["/usr/local/bin/gamja-entrypoint"]
