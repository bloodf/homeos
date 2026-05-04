# HomeOS

> One script. Any Debian/Ubuntu/Fedora box. Full home server in minutes.

HomeOS is now **script-only**: a universal shell installer that turns an existing Debian 12+, Ubuntu 22.04+, Fedora 38+, or RHEL/Rocky/Alma 9+ system into a fully configured headless home server.

The repository contains only the supported self-contained `.sh` installer and its documentation.

[![Universal Installer CI](https://github.com/bloodf/homeos/actions/workflows/installer-ci.yml/badge.svg)](https://github.com/bloodf/homeos/actions/workflows/installer-ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Quick start

Interactive:

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash
```

Minimal core install:

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash -s -- --mode minimal
```

Unattended with config:

```bash
sudo mkdir -p /etc/homeos
sudo cp universal-installer/homeos.conf.example /etc/homeos/homeos.conf
sudoedit /etc/homeos/homeos.conf

curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh \
  | sudo bash -s -- --config /etc/homeos/homeos.conf --unattended
```

Dry run:

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh \
  | sudo bash -s -- --dry-run
```

## What it can install

| Layer | Component |
| --- | --- |
| Base | packages, admin user, sudoers, data directories, security updates |
| Runtime | Docker CE, Docker Compose, Node.js, npm, pnpm, Bun |
| Network | Tailscale, Caddy, UFW/firewalld, SSH hardening |
| Management | CasaOS, Cockpit + 45Drives modules |
| Apps | Home Assistant, Jellyfin, Vaultwarden |
| Ops | Prometheus, Grafana, Watchtower, restic backups |
| Dev/AI | Claude Code, Codex, Gemini CLI, Cursor Agent, Kimi, Opencode, GitHub tools |

All major components are controlled by `yes`/`no` flags in `homeos.conf`.

## OS support

| OS | Minimum version | Notes |
| --- | --- | --- |
| Debian | 12 | Node.js 24 via NodeSource |
| Ubuntu | 22.04 LTS | Node.js 24 via NodeSource |
| Fedora | 38 | Fedora repos currently provide Node.js 20 |
| RHEL/Rocky/Alma | 9 | Best-effort RHEL-family support |

Works on bare metal, existing VMs, cloud VPSes, Proxmox guests, ARM64 systems, and containers for smoke testing.

## Configuration

Config search order:

1. `--config <path>`
2. `/etc/homeos/homeos.conf`
3. `~/.config/homeos/homeos.conf`
4. `./homeos.conf`

Example:

```bash
HOMEOS_MODE="full"
HOMEOS_UNATTENDED="yes"

INSTALL_HOMEASSISTANT="yes"
INSTALL_JELLYFIN="yes"
INSTALL_VAULTWARDEN="yes"
INSTALL_MONITORING="yes"

TAILSCALE_AUTH_KEY="tskey-auth-..."
VAULTWARDEN_ADMIN_TOKEN="..."
GRAFANA_ADMIN_PASSWORD=""        # random if empty
GRAFANA_BIND_ADDRESS="127.0.0.1" # use 0.0.0.0 for LAN or a Tailscale IP

HOMEOS_DATA_DIR="/opt/homeos"
MEDIA_PATH="/srv/media"
BACKUP_TARGET=""
```

Full template: [`universal-installer/homeos.conf.example`](universal-installer/homeos.conf.example).

## Management CLI

After installation:

```bash
homeos status          # services, containers, disk usage
homeos doctor          # runtime/service/stack checks
homeos logs <svc>      # container logs
homeos restart <svc>   # restart stack/container
homeos backup          # trigger backup
homeos config          # print /etc/homeos/homeos.conf
homeos update          # download latest installer and re-run with original config path
homeos uninstall       # uninstall HomeOS data/config
homeos --version
```

Full package/repository purge:

```bash
sudo bash install.sh uninstall --purge --yes
# or from an installed system
homeos uninstall --purge --yes
```

## Repository layout

```text
homeos/
├── .github/workflows/installer-ci.yml
├── Makefile
├── README.md
├── release-notes/v1.0.0.md
└── universal-installer/
    ├── install.sh
    ├── smoke-test.sh
    ├── homeos.conf.example
    ├── README.md
    ├── TEST-REPORT.md
    ├── RELEASE-READINESS-AUDIT.md
    ├── REVIEW-FIXES-2026-05-04.md
    └── BUGFIX-SUMMARY-2026-05-04.md
```

## Local validation

```bash
make check
make smoke
```

The GitHub Actions workflow runs ShellCheck, Bash syntax checks, and deterministic Debian container smoke tests.

## Security defaults

- Random admin password in unattended mode: `/var/lib/homeos/admin-password.txt`
- Random Grafana password when unset: `/var/lib/homeos/grafana-password.txt`
- Grafana binds to localhost by default
- SSH root login disabled; password auth disabled when admin SSH keys exist
- Firewall defaults deny inbound except HomeOS service ports
- Config expansion is restricted to simple `$VAR` / `${VAR}` expansion; command substitution is never evaluated

## License

MIT. See [LICENSE](LICENSE).
