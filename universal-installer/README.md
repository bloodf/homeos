# HomeOS Universal Installer

> One script. Any Debian or Fedora box. Full home server in minutes.

HomeOS is now a **universal shell installer** instead of a custom ISO. Run it on any existing Debian 12+, Ubuntu 22.04+, Fedora 38+, or RHEL 9+ system and get a fully configured home server.

## Why a script instead of an ISO?

| ISO Distro                                   | Universal Script                                            |
| -------------------------------------------- | ----------------------------------------------------------- | ---------- |
| Requires burning USB, bare-metal install     | Runs on existing VMs, cloud instances, or old laptops       |
| Fixed disk layout                            | Works with any existing partition scheme                    |
| Single architecture per ISO                  | Works on amd64, arm64, any QEMU/Proxmox/EC2/DigitalOcean VM |
| Hard to update                               | `homeos update` pulls latest installer and re-runs          |
| Complex build pipeline (`docker`, `xorriso`) | Just `curl                                                  | sudo bash` |

## Quick Start

### Interactive (recommended for first time)

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash
```

### Unattended (for automation)

```bash
# 1. Create your config
cat > /etc/homeos/homeos.conf <<'EOF'
HOMEOS_UNATTENDED="yes"
HOMEOS_MODE="full"
TAILSCALE_AUTH_KEY="tskey-auth-xxxxxxxxxxxx"
CADDY_DOMAIN="home.example.com"
ANTHROPIC_API_KEY="sk-ant-..."
EOF

# 2. Run
sudo bash install.sh --config /etc/homeos/homeos.conf
```

### Minimal mode (core only)

```bash
sudo bash install.sh --mode minimal
```

## What Gets Installed

### Core Infrastructure

- **Docker CE** + Buildx + Compose plugin
- **Node.js 24 LTS** + pnpm + Bun
- **systemd services** for everything

### Web UIs & Management

| Service | Port    | Description                          |
| ------- | ------- | ------------------------------------ |
| CasaOS  | `:81`   | Container dashboard                  |
| Cockpit | `:9090` | Server admin + 45Drives file sharing |
| Grafana | `:3000` | Metrics dashboards                   |

### Media & Home Automation

| Service        | Port    | Description                    |
| -------------- | ------- | ------------------------------ |
| Home Assistant | `:8123` | Smart home hub                 |
| Jellyfin       | `:8096` | Media server (Intel QSV/VAAPI) |
| Vaultwarden    | `:8222` | Password vault                 |

### Network & Access

- **Tailscale** — Zero-config VPN
- **Caddy** — Reverse proxy with automatic HTTPS
- **UFW** (Debian) or **firewalld** (RHEL) — Firewall

### AI / Dev Tools

- Claude Code, Codex, Gemini CLI, Cursor Agent, Kimi, Opencode
- GitHub dev tools (hindsight, portless, claude-context, etc.)

### Monitoring & Backups

- **Prometheus** `:9091` + **Grafana** `:3000`
- **Watchtower** — Auto-update Docker containers
- **restic** — Encrypted backups with cron schedule

## Configuration File

Create `homeos.conf` before running:

```bash
# /etc/homeos/homeos.conf
HOMEOS_ADMIN_USER="admin"
HOMEOS_MODE="full"
HOMEOS_UNATTENDED="yes"

# Components (yes/no)
INSTALL_HOMEASSISTANT="yes"
INSTALL_JELLYFIN="yes"
INSTALL_VAULTWARDEN="yes"
INSTALL_AI_CLIS="yes"

# Credentials
TAILSCALE_AUTH_KEY="tskey-auth-..."
VAULTWARDEN_ADMIN_TOKEN="..."
ANTHROPIC_API_KEY="sk-ant-..."
OPENAI_API_KEY="sk-..."

# Network
CADDY_DOMAIN="home.example.com"

# Storage
HOMEOS_DATA_DIR="/opt/homeos"
MEDIA_PATH="/srv/media"
```

**Config search order:**

1. `--config <path>` flag
2. `/etc/homeos/homeos.conf`
3. `~/.config/homeos/homeos.conf`
4. `./homeos.conf` (same directory as install.sh)

## Management

After installation, use the `homeos` CLI:

```bash
homeos status    # Show services, containers, disk usage
homeos doctor    # Health checks
homeos update    # Pull latest installer and re-run
```

## OS Support

| OS          | Minimum Version | Package Manager |
| ----------- | --------------- | --------------- |
| Debian      | 12 (Bookworm)   | apt + UFW       |
| Ubuntu      | 22.04 LTS       | apt + UFW       |
| Fedora      | 38              | dnf + firewalld |
| RHEL        | 9               | dnf + firewalld |
| Rocky Linux | 9               | dnf + firewalld |
| AlmaLinux   | 9               | dnf + firewalld |

## Architecture

```
universal-installer/
├── install.sh              # Main installer (this script)
├── homeos.conf.example     # Configuration template
├── README.md               # This file
└── lib/                    # Modular libraries (future)
```

The installer is a single self-contained script with no external dependencies beyond `curl` and standard POSIX tools. Each component is a bash function that can be individually enabled/disabled via config.

## Development

### Test locally (Debian container)

```bash
docker run --rm -it --privileged debian:12 bash
# Inside container:
apt-get update && apt-get install -y curl sudo
curl -fsSL .../install.sh | bash
```

### Dry-run mode

The installer has a built-in `--help` and shows exactly what will be installed before confirming. Set `HOMEOS_UNATTENDED=yes` to skip the confirmation prompt.

## Migration from ISO

If you previously used the HomeOS ISO:

1. Install Debian/Fedora on your target machine normally
2. Run the universal installer instead of flashing the ISO
3. Your config file replaces the preseed — same unattended experience
4. The Ansible bootstrap is now inline bash functions — no `ansible-playbook` dependency

## License

MIT
