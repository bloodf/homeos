# HomeOS documentation

HomeOS is a script-only universal installer. These docs are the source of truth for users, operators, and contributors.

## User docs

| Doc                                         | Purpose                                                                                         |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [Installation](INSTALLATION.md)             | Supported systems, install modes, interactive vs unattended installs, upgrades, and uninstall.  |
| [Configuration reference](CONFIGURATION.md) | Every important config area and how config loading works.                                       |
| [Operations guide](OPERATIONS.md)           | Day-2 `homeos` CLI usage, health checks, logs, backups, local domains, and troubleshooting.     |
| [AI integrations](AI-INTEGRATIONS.md)       | AI CLIs, Pi packages, npx skills, AI helper project library, and sanitized local MCP inventory. |
| [Security model](SECURITY.md)               | Security defaults, secret handling, network exposure, MCP isolation, and hardening guidance.    |
| [Architecture](ARCHITECTURE.md)             | Installer structure, state layout, service layout, and component boundaries.                    |
| [Layer index](LAYERS.md)                    | Quick source-of-truth map for existing and non-existent project layers.                         |
| [MCP guidance](MCP.md)                      | Project MCP policy and HomeOS installed-system MCP isolation notes.                             |

## Project process docs

| Doc                                           | Purpose                                                                   |
| --------------------------------------------- | ------------------------------------------------------------------------- |
| [Development process](DEVELOPMENT-PROCESS.md) | How to safely change the installer and docs.                              |
| [Testing](TESTING.md)                         | Test layers, TDD workflow, smoke coverage, and local verification ladder. |
| [Requirements](REQUIREMENTS.md)               | Development and target-system requirements verified from source files.    |
| [Deployment](DEPLOYMENT.md)                   | Installer delivery, CI triggers, update path, and release deployment.     |
| [Agent process](AGENT_PROCESS.md)             | Operational checklist for future coding agents.                           |
| [Agent capabilities](AGENT_CAPABILITIES.md)   | Project-local portable skills and role prompts under `.agents/`.          |
| [Release process](RELEASE-PROCESS.md)         | Versioning, validation, tagging, GitHub release, and post-release checks. |

## Quick commands

```bash
make check   # ShellCheck + bash syntax
make smoke   # deterministic Debian container smoke test
```

## Script-only rule

Do not add ISO, QEMU, preseed, image-build, or Ansible bootstrap paths. HomeOS is shipped as `universal-installer/install.sh` plus documentation.
