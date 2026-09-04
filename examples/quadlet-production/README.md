# Production Podman/Quadlet deployment

M1.5 mirrors the Docker Compose production architecture with system-level Podman Quadlet units. M1.6 adds an operations baseline with journald logging, resource guardrails, restart policy and explicit shutdown windows.

```text
Internet :80/:443
       |
     Caddy
       |
   Gamja :8080
       |
   /socket
       |
    soju :8080
```

Only Caddy publishes host ports. Soju and Gamja remain private on the `gamja-production` Podman network.

## Install

```sh
sudo mkdir -p /etc/gamja /etc/containers/systemd
sudo cp soju.conf Caddyfile /etc/gamja/
sudo cp gamja.env.example /etc/gamja/gamja.env
sudo cp *.container *.network *.volume /etc/containers/systemd/
sudo $EDITOR /etc/gamja/gamja.env
sudo systemctl daemon-reload
sudo systemctl start caddy.service
```

Starting `caddy.service` pulls in Gamja and soju. Gamja waits for the soju healthcheck before it starts, and Caddy waits for the Gamja healthcheck.

Set `GAMJA_DOMAIN` to a DNS hostname that resolves to the server. This system-level deployment intentionally binds 80/tcp, 443/tcp and 443/udp directly. For a rootless deployment, use unprivileged host ports or configure the host's privileged-port policy explicitly.

Create the first administrator after soju is healthy:

```sh
sudo podman exec -it soju sojudb -config /etc/soju/config create-user <username> -admin
sudo systemctl restart soju.service
```

## M1.6 operations baseline

The generated containers log to journald. Follow the complete stack with:

```sh
sudo journalctl -f -u caddy.service -u gamja.service -u soju.service
```

Recent logs for one component:

```sh
sudo journalctl -u gamja.service --since '30 minutes ago'
```

Resource guardrails are:

| Service | CPU quota | Memory | PIDs | Stop timeout |
| --- | ---: | ---: | ---: | ---: |
| soju | 100% | 256 MiB | 256 | 30s |
| Gamja | 50% | 128 MiB | 128 | 15s |
| Caddy | 100% | 256 MiB | 256 | 30s |

These are small-installation defaults, not sizing guarantees. Adjust them after observing real usage.

Podman 4.9.3 supports Quadlet's native `LogDriver=` and `PidsLimit=` keys but not the newer `Memory=` key. To keep Ubuntu 24.04 compatibility, the reference units therefore pass the memory ceiling through `PodmanArgs=--memory=...`; the generated container still receives the same cgroup memory limit. CPU is bounded with systemd `CPUQuota=`.

Inspect systemd policy and live Podman state:

```sh
systemctl status soju.service gamja.service caddy.service
systemctl show soju.service gamja.service caddy.service -p CPUQuotaPerSecUSec
sudo podman inspect --format 'memory={{.HostConfig.Memory}} pids={{.HostConfig.PidsLimit}} log={{.HostConfig.LogConfig.Type}}' soju gamja gamja-caddy
sudo podman stats
```

All three services use `Restart=on-failure` with a 3-second restart delay. M1.6 CI kills the Gamja container deliberately and verifies that systemd recreates it, health returns to `healthy`, and HTTPS remains usable.

## Ubuntu 24.04 and no-new-privileges

The Quadlet example deliberately does not set `NoNewPrivileges=true`. Ubuntu 24.04's packaged Podman 4.9.3/crun combination is affected by an AppArmor interaction where containers launched with `--security-opt=no-new-privileges` can be denied creation of normal TCP sockets, including an unprivileged listener on port 8080. M1.5 runtime qualification reproduced this behavior with both soju and Gamja.

This limitation is specific to the Podman/Ubuntu runtime path. The Docker Compose production deployment retains `no-new-privileges:true`. The Quadlet deployment still keeps Gamja non-root and read-only, keeps Soju and Gamja off host ports, and uses systemd/Podman health ordering.

Re-evaluate this omission when deploying on a Podman/crun/AppArmor version where the Ubuntu issue is fixed.

## Persistence

Quadlet-managed named volumes are:

- `gamja-soju-data`
- `gamja-caddy-data`
- `gamja-caddy-config`

The Soju and Caddy dependency images are pinned by OCI index digest. The Gamja image tracks this repository's `latest` build so the example follows the current container implementation.

## Validation

M1.6 CI installs Podman on Ubuntu 24.04, runs the Quadlet generator, verifies logging/resource/restart settings in the generated units, starts the real systemd stack, and verifies service ordering, health, private application ports, HTTPS delivery, WSS upgrade and restart recovery through Caddy -> Gamja -> soju.
