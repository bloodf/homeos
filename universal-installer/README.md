# HomeOS Universal Installer

> One script. Any Debian/Ubuntu/Fedora box. Full home server in minutes.

This directory contains the supported HomeOS installer. It is a single Bash script with no separate image/build pipeline.

## Quick start

Interactive:

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash
```

Unattended with config:

```bash
sudo mkdir -p /etc/homeos
sudo cp homeos.conf.example /etc/homeos/homeos.conf
sudoedit /etc/homeos/homeos.conf
sudo bash install.sh --config /etc/homeos/homeos.conf --unattended
```

Minimal mode:

```bash
sudo bash install.sh --mode minimal
```

Dry run:

```bash
sudo bash install.sh --dry-run
```

## CLI options

```text
Options:
  --config <path>       Path to config file
  --unattended          Non-interactive mode
  --mode <full|minimal> Installation mode
  --dry-run             Show what would be installed without making changes
  --skip-checks         Skip pre-flight checks
  --yes                 Auto-accept prompts
  --purge               With uninstall, also remove installed packages/repos
  --version             Show version
  --help                Show help

Commands:
  (no command)          Run installer
  uninstall             Remove HomeOS
```

## Components

| Area | Components |
| --- | --- |
| Core | base packages, admin user, sudoers, state dir |
| Runtime | Docker CE, Compose, Node.js, pnpm, Bun |
| Network | Tailscale, Caddy, UFW/firewalld, SSH hardening |
| Management | CasaOS, Cockpit + 45Drives modules |
| Apps | Home Assistant, Jellyfin, Vaultwarden |
| Ops | Prometheus, Grafana, Watchtower, restic backups |
| Dev/AI | Claude Code, Codex, Gemini CLI, Cursor Agent, Kimi, Opencode, GitHub tools |

## Config file

Config search order:

1. `--config <path>`
2. `/etc/homeos/homeos.conf`
3. `~/.config/homeos/homeos.conf`
4. `./homeos.conf`

Example:

```bash
HOMEOS_ADMIN_USER="admin"
HOMEOS_MODE="full"
HOMEOS_UNATTENDED="yes"

INSTALL_HOMEASSISTANT="yes"
INSTALL_JELLYFIN="yes"
INSTALL_VAULTWARDEN="yes"
INSTALL_MONITORING="yes"

TAILSCALE_AUTH_KEY="tskey-auth-..."
VAULTWARDEN_ADMIN_TOKEN="..."
GRAFANA_ADMIN_PASSWORD=""
GRAFANA_BIND_ADDRESS="127.0.0.1"

HOMEOS_DATA_DIR="/opt/homeos"
MEDIA_PATH="/srv/media"
BACKUP_TARGET=""
```

See [`homeos.conf.example`](homeos.conf.example) for all options.

Environment expansion is intentionally strict: only exact `$VAR` and `${VAR}` values are expanded. Command substitution is never evaluated.

## Management

After installation:

```bash
homeos status
homeos doctor
homeos logs <svc>
homeos restart <svc>
homeos backup
homeos config
homeos update
homeos uninstall
homeos --version
```

`homeos update` reuses the original config path recorded at `/var/lib/homeos/config-path` when available.

## Security defaults

- Random unattended admin password: `/var/lib/homeos/admin-password.txt`
- Random Grafana password when unset: `/var/lib/homeos/grafana-password.txt`
- Grafana binds to `127.0.0.1:3000` by default
- SSH root login disabled
- Password auth disabled when admin SSH keys exist
- Firewall defaults deny inbound except required service ports
- Third-party installer failures are warnings when safe to continue

## Uninstall

Data/config teardown only:

```bash
sudo bash install.sh uninstall
sudo bash install.sh --yes uninstall
```

Full package/repository purge:

```bash
sudo bash install.sh uninstall --purge --yes
homeos uninstall --purge --yes
```

In unattended mode without `--yes`, package purging is skipped to avoid accidental destructive removals.

## Local validation

```bash
shellcheck --severity=warning install.sh
bash -n install.sh
```

From the repository root:

```bash
make check
make smoke
```
