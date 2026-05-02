# Portable HomeOS Installer Design

Date: 2026-05-02
Status: Approved design draft

## Goal

Add a portable `homeos-install.sh` application that can install and configure HomeOS features on already-installed Linux distributions, while also becoming the reusable orchestration entrypoint for generating/bootstrapping the final HomeOS distro.

The installer must support both human-driven interactive usage and repeatable scripted usage.

## Target platforms

Initial supported platforms:

- Debian
- Ubuntu
- Fedora
- RHEL-compatible distributions

Unsupported distributions fail clearly unless the user passes an explicit force flag such as `--force-unsupported`.

## Primary design choice

Use a hybrid architecture:

- Pure Bash is the stable public entrypoint and UI layer.
- Feature modules expose a Bash interface.
- Existing Ansible bootstrap roles can be reused through an optional bridge when useful.
- Package/repository operations are abstracted across `apt` and `dnf`.

This avoids duplicating all existing bootstrap logic while still giving users a single portable `.sh` application.

## Repository layout

Proposed new structure:

```text
install/
  homeos-install.sh
  lib/
    ui.sh
    distro.sh
    pkg.sh
    profiles.sh
    runner.sh
    ansible.sh
  modules/
    base.sh
    docker.sh
    tailscale.sh
    caddy.sh
    cockpit.sh
    casaos.sh
    stacks.sh
    ai-clis.sh
    monitoring.sh
    backups.sh
    security.sh
```

Responsibilities:

- `homeos-install.sh`: argument parsing, root checks, top-level command flow.
- `lib/ui.sh`: pure Bash menu and multi-select UI.
- `lib/distro.sh`: OS and version detection.
- `lib/pkg.sh`: `apt`/`dnf` package manager abstraction.
- `lib/profiles.sh`: profiles, categories, feature registry.
- `lib/runner.sh`: dependency resolution, dry-run/apply execution, logs, state.
- `lib/ansible.sh`: optional bridge to existing `bootstrap/install.yml` and roles.
- `modules/*.sh`: feature modules with a shared interface.

## User interfaces

Interactive menu:

```bash
sudo ./install/homeos-install.sh
```

Scripted examples:

```bash
sudo ./install/homeos-install.sh --mode adopt --profile media --features docker,jellyfin,caddy --yes
sudo ./install/homeos-install.sh --mode appliance --profile full --dry-run
sudo ./install/homeos-install.sh --mode appliance --profile full --yes --confirm-appliance
```

The interactive UI must be pure Bash only. It must not require `dialog`, `whiptail`, `fzf`, Python, Node, or any other UI dependency.

## Operating modes

### Adopt mode

For machines that already have a purpose.

Default behavior:

- avoid changing hostname;
- avoid replacing users;
- avoid hardening SSH unless explicitly selected;
- avoid replacing firewall defaults unless explicitly selected;
- avoid overwriting existing reverse proxy config unless explicitly selected;
- install HomeOS features side-by-side.

### Appliance mode

For converting a distro into a HomeOS appliance.

Allowed behavior:

- set HomeOS hostname defaults;
- create/configure the admin user;
- harden SSH;
- configure firewall defaults;
- install Docker, CasaOS, Caddy, Cockpit, HomeOS CLI, audit gate, and selected stacks;
- configure the machine closer to the final HomeOS distro behavior.

Safety requirement: appliance mode requires clear confirmation in interactive mode, and scripted runs require both `--yes` and `--confirm-appliance`.

## Profiles

Initial profiles:

| Profile   | Description                                                                 |
| --------- | --------------------------------------------------------------------------- |
| `minimal` | Base tools, HomeOS CLI, package setup                                       |
| `server`  | `minimal` + Docker + Cockpit + Tailscale + Caddy                            |
| `media`   | `server` + Jellyfin + optional media-stack installers                       |
| `ai`      | `server` + AI CLIs + MCP hub + optional Ollama                              |
| `full`    | `server` + media + AI + monitoring + backups + Vaultwarden + Home Assistant |
| `custom`  | Menu-selected features only                                                 |

## Categories

Features are grouped by context and category:

- Base system
- Network & access
- Containers & orchestration
- Smart home
- Media
- NAS & storage
- AI/dev tools
- Monitoring
- Backups
- Security/audit
- Portals/UI

Interactive flow:

1. choose mode;
2. choose profile;
3. review selected features;
4. add/remove individual features by category;
5. show final plan;
6. dry-run or apply.

## Feature module contract

Each feature module exposes metadata and common functions:

```bash
feature_id="docker"
feature_name="Docker CE"
feature_category="Containers & orchestration"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="medium"

detect()      # return whether feature is already installed/configured
plan()        # print what would change
apply()       # perform install/configuration
rollback()    # optional best-effort rollback
```

The runner calls modules through this contract only. Internal module implementation can be plain Bash or a bridge to Ansible.

## Execution model

The runner must:

1. detect distro and package manager;
2. resolve profile to a feature list;
3. merge user-selected feature additions/removals;
4. resolve dependencies;
5. show a plan;
6. ask for confirmation unless non-interactive flags allow apply;
7. apply features in dependency order;
8. write state and logs;
9. print next steps.

Behavior requirements:

- `--dry-run` never mutates the system.
- `--yes` is required for non-interactive apply.
- Failed features stop the run by default.
- Already-installed features are skipped unless `--reconfigure` is passed.
- Logs go to `/var/log/homeos-install.log` during apply.
- State goes under `/var/lib/homeos/install-state/`.
- Secrets must not be printed to logs.

State layout:

```text
/var/lib/homeos/install-state/
  selected-profile
  installed-features/
  logs/
```

## Package manager abstraction

All package operations go through helper functions, never direct module-specific `apt`/`dnf` calls unless unavoidable.

Examples:

```bash
pkg_update
pkg_install curl git docker
pkg_repo_add <name> <repo-data>
pkg_service_enable docker
```

`pkg.sh` maps these to Debian/Ubuntu or Fedora/RHEL behavior.

## Safety model

The installer defaults to preview-before-apply.

Example summary:

```text
Selected mode: appliance
Selected profile: full

Will change:
  - install Docker CE
  - enable Tailscale
  - configure Caddy
  - install HomeOS CLI
  - enable audit logging
  - install selected stacks

High-risk changes:
  - create/modify admin user
  - harden SSH
  - replace firewall defaults
  - set hostname to homeos

Apply? [y/N]
```

Safeguards:

- destructive features are marked `high` risk;
- appliance mode requires a typed confirmation such as `HOMEOS`;
- non-interactive appliance runs require `--yes --confirm-appliance`;
- apply mode requires root;
- dry-run is available from both menu and CLI;
- secrets are redacted from logs and summaries.

## ISO reuse

The current ISO can keep using Debian preseed for base OS installation. On first boot, it can eventually call the portable installer:

```bash
/opt/homeos/install/homeos-install.sh \
  --mode appliance \
  --profile full \
  --yes \
  --confirm-appliance \
  --source /opt/homeos
```

This makes the portable installer the shared orchestration layer for both:

- existing-distro adoption;
- final HomeOS distro generation/bootstrap.

## Success criteria

The design is successful when:

- a user can run one Bash script on Debian/Ubuntu/Fedora/RHEL and select HomeOS features from a pure Bash menu;
- scripted installs can reproduce the same result using flags;
- adopt mode avoids unexpected takeover of existing machines;
- appliance mode can intentionally convert a distro toward full HomeOS behavior;
- module metadata supports profiles, categories, dependencies, risks, distro support, and dry-run plans;
- the ISO path can reuse the same installer entrypoint without a separate orchestration model.

## Out of scope for the first implementation

- GUI installer.
- Required `dialog`, `whiptail`, or `fzf` UI.
- Full support for Arch, Alpine, NixOS, openSUSE, or macOS.
- Perfect rollback for every feature.
- Replacing Debian preseed in the ISO build.
