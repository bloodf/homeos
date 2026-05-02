# Portable Installer

Install HomeOS features onto an already-installed Linux distribution, or convert that distro into a HomeOS appliance.

The portable installer is `install/homeos-install.sh`. Pure Bash, no UI dependencies.

## Supported distros

- Debian
- Ubuntu
- Fedora
- RHEL-compatible (Rocky, Alma)

Other distros refuse to run unless `--force-unsupported` is passed.

## Modes

| Mode        | Purpose                                  | Touches hostname/users/SSH/firewall? |
| ----------- | ---------------------------------------- | ------------------------------------ |
| `adopt`     | Add HomeOS features side-by-side         | No, unless explicitly selected       |
| `appliance` | Convert the box into a HomeOS appliance  | Yes                                  |

`appliance` mode is destructive of existing config. Interactive runs require typing `HOMEOS` to confirm. Non-interactive runs require both `--yes` and `--confirm-appliance`.

## Profiles

| Profile   | Includes                                                                  |
| --------- | ------------------------------------------------------------------------- |
| `minimal` | Base tools, HomeOS package setup                                          |
| `server`  | `minimal` + Docker + Cockpit + Tailscale + Caddy                          |
| `media`   | `server` + media stacks                                                   |
| `ai`      | `server` + AI CLIs + MCP hub                                              |
| `full`    | `server` + media + AI + monitoring + backups + security hardening         |
| `custom`  | Pick features from the menu                                               |

## Usage

Interactive menu:

```bash
sudo ./install/homeos-install.sh
```

Scripted:

```bash
# Adopt mode, server profile, add specific features, no prompts
sudo ./install/homeos-install.sh --mode adopt --profile server --features docker,caddy --yes

# Preview what appliance mode would do
sudo ./install/homeos-install.sh --mode appliance --profile full --dry-run

# Apply appliance mode non-interactively
sudo ./install/homeos-install.sh --mode appliance --profile full --yes --confirm-appliance
```

## Flags

| Flag                       | Purpose                                                |
| -------------------------- | ------------------------------------------------------ |
| `--mode {adopt\|appliance}` | Operating mode                                         |
| `--profile <name>`         | Profile to install                                     |
| `--features <csv>`         | Add/remove features (`+id`, `-id`, or plain `id`)      |
| `--yes`                    | Skip confirmations                                     |
| `--dry-run`                | Print plan only, never mutate                          |
| `--reconfigure`            | Re-apply features even if already installed            |
| `--confirm-appliance`      | Required with `--yes` for appliance mode               |
| `--force-unsupported`      | Allow running on unsupported distros                   |
| `--source <path>`          | Path to HomeOS source tree (e.g. `/opt/homeos`)        |
| `-h`, `--help`             | Print usage                                            |

## Features

Features are bash modules under `install/modules/`. Each exposes:

```bash
feature_id="docker"
feature_name="Docker CE"
feature_category="Containers & orchestration"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="medium"  # low | medium | high

detect()    # is this already installed?
plan()      # what would change?
apply()     # install/configure
rollback()  # best-effort undo
```

Built-in modules:

- `base` — package basics, HomeOS CLI prerequisites
- `docker` — Docker CE + compose
- `tailscale` — mesh VPN
- `caddy` — reverse proxy
- `cockpit` — web admin UI
- `casaos` — homelab portal
- `stacks` — HomeOS app stacks
- `ai-clis` — Claude/Codex/Gemini CLIs + MCP hub
- `monitoring` — Prometheus/Grafana
- `backups` — restic
- `security` — SSH hardening + UFW + auditd (high risk, appliance mode only)

## Execution flow

1. Detect distro + package manager.
2. Resolve profile to a feature list.
3. Merge `--features` overrides.
4. Resolve dependencies in topological order.
5. Print plan (normal-risk + high-risk groups).
6. Confirm (unless `--yes`).
7. Apply features in order. Skip already-installed unless `--reconfigure`. Stop on first failure.
8. Write logs + state.

## State and logs

- Logs: `/var/log/homeos-install.log` (secrets redacted)
- State: `/var/lib/homeos/install-state/`
  - `selected-profile`
  - `installed-features/<id>`
  - `logs/`

## Ansible bridge

Modules with an existing role under `bootstrap/roles/<id>` delegate to Ansible when present. The bridge synthesizes a single-role mini playbook against the source tree given via `--source` (or auto-detected). When Ansible is unavailable, modules fall back to native Bash apply logic.

## Use from the ISO

The ISO build is unchanged. After first boot, the ISO can call the portable installer to finalize:

```bash
/opt/homeos/install/homeos-install.sh \
  --mode appliance \
  --profile full \
  --yes \
  --confirm-appliance \
  --source /opt/homeos
```

## Safety

- `--dry-run` never mutates.
- Apply requires root (`EUID 0`).
- Already-installed features are skipped unless `--reconfigure`.
- Appliance mode is gated behind a typed confirm or `--yes --confirm-appliance`.
- Failed features stop the run.
- Secrets redacted from logs.

## Out of scope

- GUI installer.
- Required `dialog`/`whiptail`/`fzf`.
- Arch, Alpine, NixOS, openSUSE, macOS.
- Replacing the Debian preseed in the ISO build.
- Perfect rollback for every feature.
