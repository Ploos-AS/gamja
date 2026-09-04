# Reverse proxy examples

These examples put the public Gamja endpoint behind HTTPS while keeping Gamja itself on its normal unprivileged HTTP port (`8080`). The browser therefore uses HTTPS/WSS externally, while the reverse proxy talks HTTP/WebSocket to Gamja on the private container network.

## Caddy

`Caddyfile` uses Caddy's automatic HTTPS. Replace `chat.example.com` with the public DNS name and make sure ports 80/443 reach Caddy. Caddy handles WebSocket upgrades automatically and forwards the original Host plus `X-Forwarded-*` headers by default.

```text
Internet -> HTTPS/WSS -> Caddy -> HTTP/WebSocket -> Gamja :8080 -> /socket -> soju
```

## nginx

`nginx.conf` terminates TLS on port 443. Provide the certificate and private key as:

```text
/etc/nginx/tls/fullchain.pem
/etc/nginx/tls/privkey.pem
```

Replace `chat.example.com` with the public DNS name. The configuration uses the nginx-recommended `map` pattern for the `Connection` header, forwards `Upgrade`, preserves the public Host, sends `X-Forwarded-For`/`X-Real-IP`, and marks the upstream request as HTTPS through `X-Forwarded-Proto`.

## Security notes

Do not publish Gamja's port 8080 directly when using a public reverse proxy. Expose only the proxy's 80/443 ports and keep both Gamja and soju on a private container network.

The generated Gamja `/config.json` is intentionally public browser configuration. Never put credentials in it that must remain secret.

M1.2 CI validates both proxy configurations with a real WebSocket upgrade through:

```text
client -> reverse proxy -> Gamja nginx -> soju
```
