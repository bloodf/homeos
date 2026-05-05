# Operations guide

This guide covers day-2 management after HomeOS is installed.

## HomeOS CLI

```bash
homeos status
homeos doctor
homeos logs <service>
homeos restart <service>
homeos backup
homeos config
homeos domain add <name> <port> [upstream-host]
homeos domain list
homeos domain remove <name>
homeos update
homeos uninstall [--purge] [--yes]
homeos --version
```

## Health checks

```bash
homeos status
homeos doctor
```

`homeos status` prints OS, uptime, services, containers, and disk usage. `homeos doctor` runs command/service/stack checks and exits non-zero when checks fail.

Common expected failures in containers:

- systemd service checks can fail when systemd is not PID 1.
- Docker stack checks can fail when the Docker daemon is unavailable.
- Firewall commands can warn when netfilter is unavailable.

These are warnings in test containers but should be investigated on real servers.

## Logs

```bash
homeos logs homeassistant
homeos logs jellyfin
homeos logs vaultwarden
homeos logs grafana
homeos logs prometheus
homeos logs watchtower
```

The CLI prefers stack compose logs under `/opt/homeos/stacks/<service>/docker-compose.yml`, then falls back to `docker logs`.

## Restarting services

```bash
homeos restart grafana
homeos restart jellyfin
```

For systemd services:

```bash
sudo systemctl restart caddy
sudo systemctl restart dnsmasq
sudo systemctl restart cockpit.socket
```

## Local domains

HomeOS local domains use dnsmasq + Caddy.

1. dnsmasq maps `*.homeos.home.arpa` to the server IP.
2. Caddy routes individual names to local upstream ports.
3. Router/client DNS must point to the HomeOS server or use it as conditional resolver.

Commands:

```bash
homeos domain add app 3000
homeos domain add api 8080 127.0.0.1
homeos domain list
homeos domain remove app
```

Files:

| File                                       | Purpose                  |
| ------------------------------------------ | ------------------------ |
| `/etc/homeos/local-domain-root`            | Active local root.       |
| `/etc/homeos/local-domain-ip`              | Active DNS IP.           |
| `/etc/dnsmasq.d/homeos-local-domains.conf` | dnsmasq wildcard config. |
| `/etc/caddy/conf.d/*.caddy`                | Per-route Caddy files.   |

Troubleshooting:

```bash
sudo systemctl status dnsmasq
sudo systemctl status caddy
getent hosts homeos.homeos.home.arpa
curl -I http://homeos.homeos.home.arpa
```

## Monitoring

HomeOS writes the monitoring stack under:

```text
/opt/homeos/stacks/monitoring/
```

Included:

- Prometheus on host port `9091`
- node-exporter container
- Grafana on host port `3000`
- provisioned Prometheus datasource
- provisioned `HomeOS Server Overview` dashboard

Grafana password:

```bash
sudo cat /var/lib/homeos/grafana-password.txt
```

Expose Grafana beyond localhost by setting:

```bash
GRAFANA_BIND_ADDRESS="0.0.0.0"
```

or a Tailscale IP in `/etc/homeos/homeos.conf`, then run `homeos update`.

## Backups

If `BACKUP_TARGET` is configured, HomeOS installs `/etc/cron.daily/homeos-backup`.

Manual run:

```bash
homeos backup
```

If `BACKUP_TARGET` is empty, backup exits with a message instead of silently doing nothing.

## Updates

```bash
homeos update
```

The update command downloads the current `main` installer and runs it unattended with the original config path if recorded.

Before updating production systems:

```bash
homeos config
homeos doctor
```

## Uninstall and recovery

Soft uninstall:

```bash
homeos uninstall --yes
```

Purge packages/repositories where possible:

```bash
homeos uninstall --purge --yes
```

Manual cleanup locations if needed:

| Path                                       | Content                             |
| ------------------------------------------ | ----------------------------------- |
| `/opt/homeos`                              | stacks, AI project library, tools   |
| `/etc/homeos`                              | config and local-domain metadata    |
| `/var/lib/homeos`                          | install state and generated secrets |
| `/etc/caddy/conf.d`                        | local route files                   |
| `/etc/dnsmasq.d/homeos-local-domains.conf` | wildcard DNS config                 |

## Troubleshooting checklist

1. Run `homeos doctor`.
2. Check `/var/log/homeos-install.log`.
3. Check `docker ps -a`.
4. Check stack logs with `homeos logs <service>`.
5. Check systemd status for `caddy`, `dnsmasq`, `cockpit.socket`, `docker`.
6. Re-run the installer with the same config; sections are designed to be idempotent.
