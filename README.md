# HomeOS

> One script. Any Debian or Fedora box. Full home server in minutes.

HomeOS is a **universal shell installer** that turns any existing Debian 12+,
Ubuntu 22.04+, Fedora 38+, or RHEL 9+ system into a fully configured headless
home server. No USB flashing, no ISO burning, no bare-metal required.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## What you get

After running the installer, your box has:

| Layer               | What                                                       | Port              |
| ------------------- | ---------------------------------------------------------- | ----------------- |
| Container dashboard | [CasaOS](https://www.casaos.io/)                           | `:81`             |
| Smart home hub      | [Home Assistant](https://www.home-assistant.io/) (Docker)  | `:8123`           |
| Media server        | [Jellyfin](https://jellyfin.org/) with Intel QSV/VAAPI     | `:8096`           |
| NAS / file sharing  | [Cockpit](https://cockpit-project.org/) + 45Drives modules | `:9090`           |
| Reverse proxy       | [Caddy](https://caddyserver.com/) with Tailscale certs     | `:80` / `:443`    |
| Secrets vault       | [Vaultwarden](https://github.com/dani-garcia/vaultwarden)  | `:8222`           |
| Monitoring          | Prometheus + Grafana                                       | `:9091` / `:3000` |
| Auto-updates        | [Watchtower](https://containrrr.dev/watchtower/)           | —                 |
| Backups             | [Restic](https://restic.net/) cron                         | —                 |
| VPN                 | [Tailscale](https://tailscale.com/)                        | —                 |
| Dev runtime         | Node 24 LTS, Bun, pnpm, Docker CE                          | —                 |
| AI coding CLIs      | Claude Code, Codex, Gemini, Cursor, Kimi                   | —                 |

Plus 10 GitHub dev tools under `/opt/homeos/tools/`.

## Quick Start

### One-liner (Interactive)

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash
```

### With Config File (Unattended)

```bash
# 1. Create config
sudo mkdir -p /etc/homeos
cat > /etc/homeos/homeos.conf <<'EOF'
HOMEOS_UNATTENDED="yes"
TAILSCALE_AUTH_KEY="tskey-auth-xxxxxxxxxxxx"
ANTHROPIC_API_KEY="sk-ant-..."
INSTALL_JELLYFIN="yes"
INSTALL_HOMEASSISTANT="yes"
EOF

# 2. Run
sudo bash -c 'curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | bash -s -- --config /etc/homeos/homeos.conf'
```

### Minimal Mode (Core Only)

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash -s -- --mode minimal
```

### Dry Run (Preview Without Installing)

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash -s -- --dry-run
```

## OS Support

| OS                  | Minimum Version |
| ------------------- | --------------- |
| Debian              | 12 (Bookworm)   |
| Ubuntu              | 22.04 LTS       |
| Fedora              | 38              |
| RHEL / Rocky / Alma | 9               |

Works on bare metal, VMs (Proxmox/QEMU/VirtualBox), cloud (AWS/DigitalOcean/Linode), and ARM64 (Raspberry Pi, Apple Silicon VMs).

## Configuration

Create a `homeos.conf` file to customize installation:

```bash
# Components (yes/no)
INSTALL_HOMEASSISTANT="yes"
INSTALL_JELLYFIN="yes"
INSTALL_VAULTWARDEN="yes"
INSTALL_AI_CLIS="yes"
INSTALL_MONITORING="yes"

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
4. `./homeos.conf`

See [`universal-installer/homeos.conf.example`](universal-installer/homeos.conf.example) for all options.

## Management

After installation:

```bash
homeos status       # Show services, containers, disk usage
homeos doctor       # Run health checks (runtime, services, stacks, disk)
homeos logs <svc>   # View container logs (ha, jellyfin, vaultwarden, etc.)
homeos restart <svc> # Restart a service
homeos backup       # Trigger backup manually
homeos config       # Show current configuration
homeos update       # Pull latest installer and re-run
homeos --version    # Show CLI version
```

## Why a script instead of an ISO?

| Before (ISO)                             | Now (Script)                                     |
| ---------------------------------------- | ------------------------------------------------ |
| Burn USB, bare-metal install only        | Runs on existing VMs, cloud, old laptops         |
| Fixed disk layout                        | Works with any partition scheme                  |
| Single architecture per ISO              | amd64, arm64, any platform                       |
| Complex build pipeline (Docker, xorriso) | Single self-contained `.sh` file                 |
| Hard to iterate                          | Edit config, re-run instantly                    |
| No uninstall                             | `sudo ./install.sh uninstall`                    |
| No pre-flight checks                     | Validates disk, RAM, internet, OS before install |

## Repository Layout

```
homeos/
├── universal-installer/
│   ├── install.sh              # Main installer
│   ├── homeos.conf.example     # Configuration template
│   └── README.md               # Installer docs
├── install/                    # Legacy portable installer (kept for reference)
├── bootstrap/                  # Legacy Ansible bootstrap (kept for reference)
├── build/                      # Legacy ISO build (kept for reference)
├── preseed/                    # Legacy preseed (kept for reference)
├── docs/                       # Documentation
└── test/                       # Test artifacts
```

## Documentation

| Doc                                                              | What                              |
| ---------------------------------------------------------------- | --------------------------------- |
| [`universal-installer/README.md`](universal-installer/README.md) | Full installer documentation      |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)                     | How it all fits together (legacy) |
| [docs/NAS.md](docs/NAS.md)                                       | USB drives, Samba, NFS            |
| [docs/SECURITY.md](docs/SECURITY.md)                             | Threat model + hardening          |
| [docs/HARDWARE.md](docs/HARDWARE.md)                             | Supported hardware, GPU           |
| [docs/FAQ.md](docs/FAQ.md)                                       | Common questions                  |

## Security

- Default firewall denies all inbound except service ports + Tailscale
- SSH: root login disabled, password auth optional (disabled if SSH key present)
- Tailscale provides mTLS-equivalent connectivity without public DNS
- All container services run unprivileged where possible
- Vaultwarden for secrets, restic for encrypted backups

## License

MIT. See [LICENSE](LICENSE).
