# HomeOS Universal Installer v1.0.0

> One script. Any Debian or Fedora box. Full home server in minutes.

HomeOS is a **universal shell installer** that turns any Debian 12+, Ubuntu 22.04+, Fedora 38+, or RHEL 9+ system into a fully configured home server.

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

### Dry run (preview without installing)

```bash
sudo bash install.sh --dry-run
```

## CLI Options

```
Options:
  --config <path>      Path to config file
  --unattended         Non-interactive mode (requires config)
  --mode <full|minimal> Installation mode
  --dry-run            Show what would be installed without making changes
  --skip-checks        Skip pre-flight checks
  --yes                Auto-accept prompts in interactive mode
  --purge              With uninstall, also remove installed packages/repos
  --version            Show version
  --help               Show help

Commands:
  (no command)         Run installer
  uninstall            Remove HomeOS (preserves Docker, Node.js, system packages)
```

## What Gets Installed

### Core Infrastructure

- **Base system** — curl, git, vim, tmux, htop, btop, fzf, ripgrep, build tools, Python
- **Docker CE** + Buildx + Compose plugin
- **Node.js 24 LTS** + pnpm + Bun
- **systemd services** for everything (gracefully skipped in containers/WSL)

### Web UIs & Management

| Service | Port    | Description                          |
| ------- | ------- | ------------------------------------ |
| CasaOS  | `:81`   | Container dashboard                  |
| Cockpit | `:9090` | Server admin + 45Drives file sharing |
| Grafana | `127.0.0.1:3000` by default | Metrics dashboards |

### Media & Home Automation

| Service        | Port    | Description                    |
| -------------- | ------- | ------------------------------ |
| Home Assistant | `:8123` | Smart home hub                 |
| Jellyfin       | `:8096` | Media server (Intel QSV/VAAPI) |
| Vaultwarden    | `:8222` | Password vault                 |

### Network & Access

- **Tailscale** — Zero-config VPN (auto-authenticates with auth key)
- **Caddy** — Reverse proxy with automatic HTTPS
- **UFW** (Debian) or **firewalld** (RHEL) — Firewall with HomeOS ports pre-configured
- **SSH hardening** — Disable root login, key auth preferred, keepalive settings

### AI / Dev Tools

- Claude Code, Codex, Gemini CLI, Cursor Agent, Kimi, Opencode
- GitHub dev tools (hindsight, portless, claude-context, etc.)
- API keys injected into `~/.bashrc` (idempotent — never duplicated)

### Monitoring & Backups

- **Prometheus** `:9091` + **Grafana** `:3000`
- **Watchtower** — Auto-update Docker containers daily
- **restic** — Encrypted backups with cron schedule
- **fail2ban** — Brute-force protection
- **unattended-upgrades** (Debian) — Automatic security updates

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
GRAFANA_ADMIN_PASSWORD=""  # optional; random password generated if empty
GRAFANA_BIND_ADDRESS="127.0.0.1"  # use 0.0.0.0 for LAN or a Tailscale IP
ANTHROPIC_API_KEY="sk-ant-..."
OPENAI_API_KEY="sk-..."

# Network
CADDY_DOMAIN="home.example.com"
TAILNET_NAME="my-home"

# Storage
HOMEOS_DATA_DIR="/opt/homeos"
MEDIA_PATH="/srv/media"
BACKUP_TARGET="s3:s3.amazonaws.com/my-bucket"

# Extra firewall ports
EXTRA_TCP_PORTS="8443 8080"
```

**Config search order:**

1. `--config <path>` flag
2. `/etc/homeos/homeos.conf`
3. `~/.config/homeos/homeos.conf`
4. `./homeos.conf` (same directory as install.sh)

**Environment variable expansion:** Simple values like `ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}` or `ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY` are expanded at load time. Command substitution is intentionally not evaluated.

## Management

After installation, use the `homeos` CLI:

```bash
homeos status       # Show services, containers, disk usage
homeos doctor       # Health checks (runtime, services, stacks, disk)
homeos logs <svc>   # View container logs (ha, jellyfin, vaultwarden, etc.)
homeos restart <svc> # Restart a service
homeos backup       # Trigger backup manually
homeos config       # Show current configuration
homeos update       # Pull latest installer and re-run with the original config path
homeos --version    # Show CLI version
```

## Pre-Flight Checks

Before installing, the script validates:

- **Disk space** ≥ 10GB available
- **RAM** ≥ 2GB (≥ 4GB recommended for full mode)
- **Internet connectivity** (can reach GitHub)
- **OS compatibility** (Debian 12+, Ubuntu 22.04+, Fedora 38+, RHEL 9+)

Use `--skip-checks` to bypass. In `--dry-run` mode, checks are previewed but not executed.

## Security

- **Random admin password** generated in unattended mode (stored securely in `/var/lib/homeos/admin-password.txt`)
- **Random Grafana password** generated when monitoring is enabled and `GRAFANA_ADMIN_PASSWORD` is empty (stored in `/var/lib/homeos/grafana-password.txt`)
- **Grafana localhost binding** by default (`GRAFANA_BIND_ADDRESS="127.0.0.1"`); set `0.0.0.0` for LAN access or a Tailscale IP for tailnet-only access
- **SSH hardening** — root login disabled, password auth only until SSH key is present
- **Firewall** — Only required ports open (22, 80, 443, 8123, 8096, 8222, 3000, 9091, etc.)
- **Fail2ban** — Brute-force protection on SSH
- **API keys** — Appended to admin `~/.bashrc` only once (idempotent, never duplicated)
- **Secrets** — Config file supports `${VAR}` syntax for environment variable injection

## OS Support

| OS          | Minimum Version | Package Manager | Tested   |
| ----------- | --------------- | --------------- | -------- |
| Debian      | 12 (Bookworm)   | apt + UFW       | ✅       |
| Ubuntu      | 22.04 LTS       | apt + UFW       | ✅ 24.04 |
| Fedora      | 38              | dnf + firewalld | ✅ 40    |
| RHEL        | 9               | dnf + firewalld | —        |
| Rocky Linux | 9               | dnf + firewalld | —        |
| AlmaLinux   | 9               | dnf + firewalld | —        |

**Known limitations:**

- Fedora provides Node.js v20 in default repos (not v24). The installer accepts this. For v24 on Fedora, use manual NodeSource or build from source.
- CasaOS install script may warn on Fedora (upstream limitation).

## Architecture

```
universal-installer/
├── install.sh              # Main installer (~1,200 lines, shellcheck-clean)
├── homeos.conf.example     # Configuration template
├── README.md               # This file
├── TEST-REPORT.md          # Cross-platform test results
└── RELEASE-READINESS-AUDIT.md  # PM/CTO audit checklist
```

The installer is a single self-contained script with no external dependencies beyond `curl` and standard POSIX tools. Each component is a bash function that can be individually enabled/disabled via config.

## Uninstall

To remove HomeOS (preserves Docker, Node.js, and system packages):

```bash
sudo bash install.sh uninstall
# Non-interactive teardown:
sudo bash install.sh --yes uninstall
```

This stops all HomeOS containers, removes Docker volumes (optional), and deletes HomeOS-owned files including `/opt/homeos`, `/etc/homeos`, the SSH hardening drop-in, the HomeOS sudoers file, generated HomeOS secrets, and the `homeos` CLI. Docker, Node.js, Caddy, Cockpit, and other system packages are preserved.

For a full purge that also removes HomeOS-installed packages and package repositories:

```bash
sudo bash install.sh uninstall --purge --yes
# or from an installed system:
homeos uninstall --purge --yes
```

In unattended mode without `--yes`, package purging is intentionally skipped to avoid accidental destructive removals.

## Development

### Test locally (Debian container)

```bash
docker run --rm -it --privileged debian:12 bash
# Inside container:
apt-get update && apt-get install -y curl sudo
curl -fsSL .../install.sh | bash
```

### Run tests

```bash
# Debian full mode
docker run --rm -it debian:12 bash -c "
  apt-get update && apt-get install -y curl sudo
  curl -fsSL https://.../install.sh | bash -s -- --unattended --mode full
"
```

### Shellcheck

```bash
shellcheck --severity=warning universal-installer/install.sh
```

## Migration from ISO

If you previously used the HomeOS ISO:

1. Install Debian/Fedora on your target machine normally
2. Run the universal installer instead of flashing the ISO
3. Your config file replaces the preseed — same unattended experience
4. The Ansible bootstrap is now inline bash functions — no `ansible-playbook` dependency

## Changelog

### v1.0.0

- Pre-flight checks (disk, RAM, internet, OS)
- `--dry-run`, `--skip-checks`, `--yes` flags
- Random admin password generation in unattended mode
- State tracking to `/var/lib/homeos/install.state`
- Uninstall command
- Enhanced `homeos` CLI: `logs`, `restart`, `backup`, `config`, `--version`
- Stack health checks in `homeos doctor`
- Auto-run health check after install
- Cross-platform testing on Debian 12, Ubuntu 24.04, Fedora 40

## License

MIT
