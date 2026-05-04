# Architecture

HomeOS is intentionally small: one installer script, one smoke-test script, one example config, and documentation.

## Non-goals

HomeOS does not ship or maintain:

- ISO images
- QEMU test images
- preseed files
- Ansible bootstrap roles
- image build pipelines

The supported install path is always `universal-installer/install.sh` on an existing machine.

## Repository layout

```text
homeos/
├── .github/workflows/installer-ci.yml
├── docs/
├── release-notes/
├── universal-installer/
│   ├── install.sh
│   ├── smoke-test.sh
│   ├── homeos.conf.example
│   ├── README.md
│   └── TEST-REPORT.md
├── Makefile
└── README.md
```

## Installer structure

`universal-installer/install.sh` is organized into sections:

1. metadata/default config
2. logging and OS detection
3. config loading and safe expansion
4. interactive checklist selection
5. package/service helpers
6. component installers
7. uninstall logic
8. embedded `homeos` CLI writer
9. parse args/main flow

The installer is Bash and must remain ShellCheck clean at warning severity.

## State layout

| Path | Purpose |
| --- | --- |
| `/etc/homeos/homeos.conf` | System config. |
| `/var/lib/homeos/install.state` | Install timestamps/state. |
| `/var/lib/homeos/config-path` | Original config path for updates. |
| `/var/lib/homeos/admin-password.txt` | Generated unattended admin password. |
| `/var/lib/homeos/grafana-password.txt` | Generated Grafana password. |
| `/opt/homeos/stacks` | Docker Compose stacks. |
| `/opt/homeos/tools` | Cloned helper tools. |
| `/opt/homeos/ai` | AI project library and shared skills/agents. |
| `/var/log/homeos-install.log` | Installer log. |

## Component boundaries

| Component | Boundary |
| --- | --- |
| Base | OS packages, user, sudoers, directories. |
| Docker | Docker engine/repo and default address pool. |
| Node | Node/npm/corepack/pnpm/Bun. |
| Network | Tailscale, Caddy, dnsmasq, firewall. |
| Stacks | Docker Compose files under `/opt/homeos/stacks`. |
| AI tooling | AI CLI installers, Pi packages, npx skills, AI project links. |
| Monitoring | Prometheus/node-exporter/Grafana stack and provisioning files. |
| Backups | restic package and cron script. |

## Idempotency model

Sections are designed to be re-runnable:

- existing commands/packages are checked before install when practical
- config files are overwritten only when HomeOS owns them
- Docker Compose stacks are regenerated from config and started if possible
- third-party installer failures are warnings when continuing is safer

## Embedded CLI

The installer writes `/usr/local/bin/homeos`. This CLI is generated from a heredoc inside `install.sh`, so changes to CLI behavior must be made in the installer and covered by smoke tests where possible.

## Testing architecture

`make check`:

- ShellCheck at warning severity
- `bash -n` for installer and smoke test

`make smoke`:

- runs `universal-installer/smoke-test.sh` in Debian Bookworm Docker
- verifies config injection safety
- verifies uninstall parser behavior
- verifies Grafana generated password/bind/dashboard files
- verifies local domain config
- verifies AI project isolation/linking in manifest-only mode

## CI

GitHub Actions runs the same checks on push/PR via `.github/workflows/installer-ci.yml`.
