# Installation guide

## Supported systems

HomeOS installs onto an existing Linux machine.

| OS family       | Supported versions | Notes                                                                |
| --------------- | ------------------ | -------------------------------------------------------------------- |
| Debian          | 12+                | Primary target. Uses apt repositories for Docker, Caddy, NodeSource. |
| Ubuntu          | 22.04 LTS+         | Primary target. Best choice for Coolify.                             |
| Fedora          | 38+                | Best effort; Fedora repo Node may lag NodeSource.                    |
| RHEL/Rocky/Alma | 9+                 | Best effort RHEL-family support.                                     |

Supported environments: bare metal, VPS, Proxmox/VMs, ARM64 machines, and containers for smoke testing. The installer degrades gracefully when systemd or Docker daemon access is unavailable.

## Install modes

### Interactive full install

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash
```

If `whiptail` is installed and the terminal is interactive, HomeOS shows checklists. Highlight an item to read help for what it installs and what to think about before enabling it.

### Minimal core install

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh \
  | sudo bash -s -- --mode minimal
```

Minimal mode disables application stacks, AI tooling, monitoring, and backups. It is useful for testing or preparing a base server.

### Unattended install

```bash
sudo mkdir -p /etc/homeos
sudo cp universal-installer/homeos.conf.example /etc/homeos/homeos.conf
sudoedit /etc/homeos/homeos.conf

curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh \
  | sudo bash -s -- --config /etc/homeos/homeos.conf --unattended
```

Unattended mode uses the config file and skips prompts. If no admin password is provided interactively, HomeOS creates one and stores it at `/var/lib/homeos/admin-password.txt`.

### Dry run

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh \
  | sudo bash -s -- --dry-run
```

Dry run loads config and prints the components that would be installed. It does not modify the system.

## Config file resolution

First match wins:

1. `--config <path>`
2. `/etc/homeos/homeos.conf`
3. `~/.config/homeos/homeos.conf`
4. `./homeos.conf`
5. `homeos.conf.example` next to the installer script

When installed with `--config`, HomeOS records the path in `/var/lib/homeos/config-path` so `homeos update` can reuse it.

## Upgrade

From an installed system:

```bash
homeos update
```

This downloads the latest installer from `main` and re-runs it in unattended mode using the recorded config path when available.

Manual upgrade:

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh \
  | sudo bash -s -- --config /etc/homeos/homeos.conf --unattended
```

## Uninstall

Remove HomeOS data/config but keep packages:

```bash
homeos uninstall --yes
```

Remove HomeOS plus HomeOS-installed packages/repositories where possible:

```bash
homeos uninstall --purge --yes
```

Uninstall does not silently delete Docker volumes unless confirmed. Review prompts carefully on interactive systems.

## Network access after install

Common ports:

| Service        | Default URL                        |
| -------------- | ---------------------------------- |
| CasaOS         | `http://SERVER_IP:81`              |
| Cockpit        | `https://SERVER_IP:9090`           |
| Home Assistant | `http://SERVER_IP:8123`            |
| Jellyfin       | `http://SERVER_IP:8096`            |
| Vaultwarden    | `http://SERVER_IP:8222`            |
| Coolify        | `http://SERVER_IP:8000`            |
| Grafana        | `http://127.0.0.1:3000` by default |

Grafana intentionally binds to localhost unless `GRAFANA_BIND_ADDRESS` is changed.

## Local domains

When enabled, HomeOS runs dnsmasq and maps `*.homeos.home.arpa` to the server IP. Point your router/client DNS at HomeOS or configure a conditional resolver for the selected root.

Manage routes:

```bash
homeos domain add app 3000
homeos domain list
homeos domain remove app
```

This creates Caddy routes such as `app.homeos.home.arpa -> localhost:3000`.
