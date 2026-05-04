# HomeOS documentation

HomeOS is a script-only universal installer. These docs are the source of truth for users, operators, and contributors.

## User docs

| Doc | Purpose |
| --- | --- |
| [Installation](INSTALLATION.md) | Supported systems, install modes, interactive vs unattended installs, upgrades, and uninstall. |
| [Configuration reference](CONFIGURATION.md) | Every important config area and how config loading works. |
| [Operations guide](OPERATIONS.md) | Day-2 `homeos` CLI usage, health checks, logs, backups, local domains, and troubleshooting. |
| [AI integrations](AI-INTEGRATIONS.md) | AI CLIs, Pi packages, npx skills, AI helper project library, and sanitized local MCP inventory. |
| [Security model](SECURITY.md) | Security defaults, secret handling, network exposure, MCP isolation, and hardening guidance. |
| [Architecture](ARCHITECTURE.md) | Installer structure, state layout, service layout, and component boundaries. |

## Project process docs

| Doc | Purpose |
| --- | --- |
| [Development process](DEVELOPMENT-PROCESS.md) | How to safely change the installer and docs. |
| [Release process](RELEASE-PROCESS.md) | Versioning, validation, tagging, GitHub release, and post-release checks. |

## Quick commands

```bash
make check   # ShellCheck + bash syntax
make smoke   # deterministic Debian container smoke test
```

## Script-only rule

Do not add ISO, QEMU, preseed, image-build, or Ansible bootstrap paths. HomeOS is shipped as `universal-installer/install.sh` plus documentation.
