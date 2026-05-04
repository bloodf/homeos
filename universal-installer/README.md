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

| Area       | Components                                                                                         |
| ---------- | -------------------------------------------------------------------------------------------------- |
| Core       | base packages, admin user, sudoers, state dir                                                      |
| Runtime    | Docker CE, Compose, Node.js, pnpm, Bun                                                             |
| Network    | Tailscale, Caddy, local wildcard domains, UFW/firewalld, SSH hardening                             |
| Platform   | Coolify for hosting apps, databases, and websites                                                  |
| Management | CasaOS, Cockpit + 45Drives modules                                                                 |
| Apps       | Home Assistant, Jellyfin, Vaultwarden                                                              |
| Ops        | Prometheus, node-exporter, Grafana dashboard, Watchtower, restic backups                           |
| Dev/AI     | Claude Code, Codex, Gemini CLI, Cursor, Kimi, Opencode, Pi + packages, isolated AI project library |

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
INSTALL_COOLIFY="yes"
INSTALL_LOCAL_DOMAINS="yes"
INSTALL_PI="yes"
INSTALL_AI_SKILLS="yes"
INSTALL_AI_PROJECTS="yes"

AI_SKILL_INSTALLS="vercel-labs/skills|claude-code,codex,opencode,pi|find-skills"
AI_PROJECTS="all"
AI_PROJECT_TOOLS="claude,opencode,openagent,pi,codex,cursor,gemini"
AI_PROJECT_TARGETS=""
LOCAL_DOMAIN_ROOT="homeos.home.arpa"
LOCAL_DOMAIN_SERVER_IP=""
TAILSCALE_AUTH_KEY="tskey-auth-..."
VAULTWARDEN_ADMIN_TOKEN="..."
GRAFANA_ADMIN_PASSWORD=""
GRAFANA_BIND_ADDRESS="127.0.0.1"

HOMEOS_DATA_DIR="/opt/homeos"
MEDIA_PATH="/srv/media"
BACKUP_TARGET=""
```

See [`homeos.conf.example`](homeos.conf.example) for all options.

Full documentation index: [`../docs/README.md`](../docs/README.md). Key guides:

- [`../docs/INSTALLATION.md`](../docs/INSTALLATION.md)
- [`../docs/CONFIGURATION.md`](../docs/CONFIGURATION.md)
- [`../docs/OPERATIONS.md`](../docs/OPERATIONS.md)
- [`../docs/SECURITY.md`](../docs/SECURITY.md)
- [`../docs/DEVELOPMENT-PROCESS.md`](../docs/DEVELOPMENT-PROCESS.md)
- [`../docs/RELEASE-PROCESS.md`](../docs/RELEASE-PROCESS.md)

Environment expansion is intentionally strict: only exact `$VAR` and `${VAR}` values are expanded. Command substitution is never evaluated.

### AI skills and project library

Interactive installs use `whiptail` checklists when available. Highlight an item to see help for what that component, skill package, or agent target does and what to consider before enabling it.

`INSTALL_AI_SKILLS=yes` uses `npx skills` with `AI_SKILL_INSTALLS` records formatted as `source|agents|skills`, so one install can choose many skills and target agents.

`INSTALL_AI_PROJECTS=yes` clones helper repos into `/opt/homeos/ai/projects` and writes `/opt/homeos/ai/manifest.tsv`. Use `AI_PROJECTS` to select repos, `AI_PROJECT_TOOLS` to choose eligible tools, and `AI_PROJECT_TARGETS` for per-project overrides such as `A11Y.md:shared,claude,opencode`. Shared skills/agents are symlinked into each selected tool, but MCP servers and plugins remain contained per tool and HomeOS does not edit global MCP configuration files.

See [`../docs/AI-INTEGRATIONS.md`](../docs/AI-INTEGRATIONS.md) for the full source/repo inventory and local MCP/skill findings.

## Management

After installation:

```bash
homeos status
homeos doctor
homeos logs <svc>
homeos restart <svc>
homeos backup
homeos config
homeos domain add app 3000
homeos domain list
homeos update
homeos uninstall
homeos --version
```

`homeos update` reuses the original config path recorded at `/var/lib/homeos/config-path` when available.

## Security defaults

- Random unattended admin password: `/var/lib/homeos/admin-password.txt`
- Random Grafana password when unset: `/var/lib/homeos/grafana-password.txt`
- Provisioned Grafana "HomeOS Server Overview" dashboard for CPU, RAM, disk, and network
- Grafana binds to `127.0.0.1:3000` by default
- Local wildcard DNS maps `*.homeos.home.arpa` to the HomeOS server when clients use HomeOS/router DNS
- AI project integrations keep per-tool MCP/plugin directories isolated while sharing only skills and agents
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
