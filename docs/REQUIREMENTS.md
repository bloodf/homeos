# Requirements

This file records requirements verified from repository source files. Do not add requirements here unless they are backed by `install.sh`, `Makefile`, CI, or docs.

## Development requirements

| Tool | Required for | Source |
| --- | --- | --- |
| Bash | syntax checks and installer execution | `Makefile`, `universal-installer/install.sh` |
| ShellCheck | static analysis | `Makefile` |
| Docker or compatible daemon | `make smoke` Debian container test | `Makefile` |
| Git | diff, commit, tag, release workflow | `docs/RELEASE-PROCESS.md` |
| GitHub CLI `gh` | release and CI monitoring commands | `docs/RELEASE-PROCESS.md` |

`make smoke` pulls/runs `debian:bookworm` and mounts the installer scripts read-only into the container.

## Target-system requirements

HomeOS installs onto an existing Linux system. Supported versions are documented in `docs/INSTALLATION.md` and enforced as recommendations/warnings in `universal-installer/install.sh`:

| OS family | Version noted by docs/source |
| --- | --- |
| Debian | 12+ |
| Ubuntu | 22.04 LTS+ |
| Fedora | 38+ |
| RHEL/Rocky/Alma | 9+ |

The installer supports bare metal, VMs, VPSes, ARM64 systems, and containers for smoke testing. Some service operations warn or degrade when systemd, Docker daemon access, firewall capabilities, or package manager features are unavailable.

## Package managers and external installers

The installer uses OS package managers and upstream installers depending on enabled components:

- `apt`/Debian-family repositories for Debian and Ubuntu paths
- `dnf`/RHEL-family repositories for Fedora/RHEL/Rocky/Alma paths
- Docker CE repositories where configured
- NodeSource on Debian/Ubuntu paths for Node.js
- upstream install scripts for selected third-party components such as Coolify or AI CLIs
- `npx skills` for AI skill packages when enabled

Review `universal-installer/install.sh` before changing these paths.

## Environment and config files

Committed example config:

- `universal-installer/homeos.conf.example`

Runtime config search order in `install.sh`:

1. `--config <path>`
2. `/etc/homeos/homeos.conf`
3. `~/.config/homeos/homeos.conf`
4. `./homeos.conf`
5. `homeos.conf.example` next to the installer script

Do not commit real runtime config containing secrets.
