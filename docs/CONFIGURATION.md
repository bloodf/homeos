# Configuration reference

HomeOS configuration is shell-style `KEY="value"` data loaded by `universal-installer/install.sh`.

## Safety rules

- Only known keys are accepted.
- Command substitution is never evaluated.
- Config expansion is limited to exact `$VAR` or `${VAR}` values.
- Secret values should live in a root-owned config file with mode `0600`.

Recommended location:

```bash
/etc/homeos/homeos.conf
```

Config search order in `install.sh`:

1. `--config <path>`
2. `/etc/homeos/homeos.conf`
3. `~/.config/homeos/homeos.conf`
4. `./homeos.conf`
5. `homeos.conf.example` next to the installer script

## Core settings

| Key                 | Default       | Description                                                 |
| ------------------- | ------------- | ----------------------------------------------------------- |
| `HOMEOS_ADMIN_USER` | `admin`       | Admin user created/managed by HomeOS.                       |
| `HOMEOS_ADMIN_HOME` | `/home/admin` | Home directory for the admin user.                          |
| `HOMEOS_MODE`       | `full`        | `full` or `minimal`. Minimal disables most optional stacks. |
| `HOMEOS_UNATTENDED` | `no`          | Set `yes` for non-interactive installs.                     |
| `HOMEOS_DATA_DIR`   | `/opt/homeos` | Root for HomeOS stacks, tools, and AI project library.      |
| `MEDIA_PATH`        | `/srv/media`  | Media storage path used by media stacks.                    |

## Component flags

All are `yes` or `no`.

| Key                     | What it controls                                              |
| ----------------------- | ------------------------------------------------------------- |
| `INSTALL_BASE`          | Base packages, admin user, directories.                       |
| `INSTALL_DOCKER`        | Docker CE and Compose plugin.                                 |
| `INSTALL_NODE`          | Node.js, npm, pnpm, Bun.                                      |
| `INSTALL_TAILSCALE`     | Tailscale install and optional auth.                          |
| `INSTALL_CADDY`         | Caddy reverse proxy.                                          |
| `INSTALL_LOCAL_DOMAINS` | dnsmasq wildcard DNS and local route support.                 |
| `INSTALL_COOLIFY`       | Coolify app platform.                                         |
| `INSTALL_CASAOS`        | CasaOS web dashboard.                                         |
| `INSTALL_COCKPIT`       | Cockpit and 45Drives modules where supported.                 |
| `INSTALL_HOMEASSISTANT` | Home Assistant Docker stack.                                  |
| `INSTALL_JELLYFIN`      | Jellyfin Docker stack.                                        |
| `INSTALL_VAULTWARDEN`   | Vaultwarden Docker stack.                                     |
| `INSTALL_FIREWALL`      | UFW/firewalld rules.                                          |
| `INSTALL_SSH_HARDEN`    | SSH root-login/auth hardening.                                |
| `INSTALL_AI_CLIS`       | Claude Code, Codex, Gemini CLI, Cursor Agent, Kimi, OpenCode. |
| `INSTALL_PI`            | Pi coding agent and configured Pi packages.                   |
| `INSTALL_AI_SKILLS`     | `npx skills` package installation.                            |
| `INSTALL_AI_PROJECTS`   | AI helper repository library and per-tool links.              |
| `INSTALL_GITHUB_TOOLS`  | GitHub helper repositories in the HomeOS tools dir.           |
| `INSTALL_MONITORING`    | Prometheus, node-exporter, Grafana dashboard.                 |
| `INSTALL_BACKUPS`       | restic backup script.                                         |

## Network and domains

| Key                      | Default            | Description                                       |
| ------------------------ | ------------------ | ------------------------------------------------- |
| `TAILNET_NAME`           | empty              | Optional tailnet name for display/docs.           |
| `TAILSCALE_AUTH_KEY`     | empty              | Optional auth key for unattended Tailscale login. |
| `CADDY_DOMAIN`           | empty              | Optional public domain for Caddy reverse proxy.   |
| `LOCAL_DOMAIN_ROOT`      | `homeos.home.arpa` | Wildcard local DNS root.                          |
| `LOCAL_DOMAIN_SERVER_IP` | empty              | IP for wildcard DNS. Auto-detected when empty.    |
| `EXTRA_TCP_PORTS`        | empty              | Additional TCP ports for firewall.                |
| `EXTRA_UDP_PORTS`        | empty              | Additional UDP ports for firewall.                |

## Secrets

| Key                       | Description                                                              |
| ------------------------- | ------------------------------------------------------------------------ |
| `VAULTWARDEN_ADMIN_TOKEN` | Vaultwarden admin token. Set a strong value before exposing Vaultwarden. |
| `GRAFANA_ADMIN_PASSWORD`  | Grafana admin password. Randomly generated if empty.                     |
| `ANTHROPIC_API_KEY`       | Optional API key exported into admin shell rc.                           |
| `OPENAI_API_KEY`          | Optional API key exported into admin shell rc.                           |
| `GOOGLE_API_KEY`          | Optional API key exported into admin shell rc.                           |

Generated secrets:

| File                                   | Purpose                     |
| -------------------------------------- | --------------------------- |
| `/var/lib/homeos/admin-password.txt`   | Unattended admin password.  |
| `/var/lib/homeos/grafana-password.txt` | Generated Grafana password. |

## Monitoring

| Key                    | Default     | Description                                                                   |
| ---------------------- | ----------- | ----------------------------------------------------------------------------- |
| `GRAFANA_BIND_ADDRESS` | `127.0.0.1` | Grafana bind address. Use `0.0.0.0` for LAN or Tailscale IP for tailnet-only. |

Prometheus is exposed on host port `9091` and Grafana on `3000` at the chosen bind address.

## AI skills

`AI_SKILL_INSTALLS` uses semicolon-separated records:

```bash
source|agent1,agent2|skill1,skill2;source|agents|skills
```

Examples:

```bash
AI_SKILL_INSTALLS="vercel-labs/skills|claude-code,codex|find-skills"
AI_SKILL_INSTALLS="Leonxlnx/taste-skill|claude-code,opencode,pi|*"
```

Supported aliases:

| Alias                                  | Normalized target |
| -------------------------------------- | ----------------- |
| `claude`, `claude_code`, `claude-code` | `claude-code`     |
| `opencode`, `open-code`                | `opencode`        |
| `kimi`                                 | `kimi-cli`        |
| `gemini`                               | `gemini-cli`      |

See [AI integrations](AI-INTEGRATIONS.md) for the full default list.

## AI project library

| Key                       | Default                                            | Description                                                   |
| ------------------------- | -------------------------------------------------- | ------------------------------------------------------------- |
| `AI_PROJECTS`             | `all`                                              | `all` or a space/comma-separated project list.                |
| `AI_PROJECT_TOOLS`        | `claude,opencode,openagent,pi,codex,cursor,gemini` | Eligible target tools.                                        |
| `AI_PROJECT_TARGETS`      | empty                                              | Per-project overrides, e.g. `A11Y.md:shared,claude,opencode`. |
| `AI_PROJECT_INSTALL_MODE` | `clone`                                            | `clone` or `manifest-only`.                                   |

## Docker and backups

| Key                    | Default         | Description                                                   |
| ---------------------- | --------------- | ------------------------------------------------------------- |
| `DOCKER_NETWORK_RANGE` | `172.30.0.0/16` | Default Docker address pool added by HomeOS.                  |
| `BACKUP_TARGET`        | empty           | restic repository/path. If empty, backup job warns and exits. |
| `TIMEZONE`             | empty           | Timezone for containers. Empty means auto/default behavior.   |

## Validating config

```bash
sudo bash universal-installer/install.sh --config /etc/homeos/homeos.conf --dry-run
```
