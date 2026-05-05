---
name: project-docs-sync
description: Use when HomeOS code, config, commands, CI, release process, security behavior, or agent process changes may require documentation updates.
---

# Project Docs Sync

Use source files first; docs describe verified HomeOS behavior only.

## Docs map

| Topic | Docs |
| --- | --- |
| Overview/layout | `README.md`, `docs/README.md` |
| Install/update/uninstall | `docs/INSTALLATION.md`, `universal-installer/README.md` |
| Config keys/defaults/secrets | `docs/CONFIGURATION.md`, `universal-installer/homeos.conf.example` |
| CLI/day-2 ops | `docs/OPERATIONS.md` |
| Architecture/layers | `docs/ARCHITECTURE.md`, `docs/LAYERS.md` |
| Tests/dev flow | `docs/TESTING.md`, `docs/DEVELOPMENT-PROCESS.md` |
| Deployment/CI/release | `docs/DEPLOYMENT.md`, `docs/RELEASE-PROCESS.md` |
| Security/MCP/AI | `docs/SECURITY.md`, `docs/AI-INTEGRATIONS.md`, `docs/MCP.md` |
| Agent process | `AGENTS.md`, `docs/AGENT_PROCESS.md`, `docs/AGENT_CAPABILITIES.md`, `.agents/` |

## Source of truth

- installer: `universal-installer/install.sh`
- config example: `universal-installer/homeos.conf.example`
- commands: `Makefile`, embedded help in `install.sh`
- tests: `universal-installer/smoke-test.sh`
- CI: `.github/workflows/installer-ci.yml`

## Rules

- Do not invent commands, env vars, ports, APIs, deployments, or coverage.
- If unknown, write how to verify instead of guessing.
- Do not document generated target-system files as repo source.
- Keep docs concrete and HomeOS-specific.
- Remove vague filler when touched.

## Verification checklist

```bash
git diff --check
bash -n universal-installer/install.sh
bash -n universal-installer/smoke-test.sh
make check
```

Also verify referenced paths exist and scan changed docs/config for secrets.
