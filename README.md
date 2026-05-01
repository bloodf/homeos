# HomeOS

> Flash one USB. Walk away. Get a fully configured headless home server reachable only via SSH and Tailscale.

HomeOS is a custom Debian 13.4 (Trixie) installer ISO that turns a bare-metal box
into a full home server in a single unattended install + first-boot bootstrap. No
screens, no GUIs, no manual configuration steps after `dd`.

[![Build ISO](https://github.com/bloodf/homeos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/bloodf/homeos/actions/workflows/build-iso.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## What you get

After first boot completes, the box is simultaneously:

| Layer               | What                                                                                                                                        | Port           |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| Container dashboard | [CasaOS](https://www.casaos.io/)                                                                                                            | `:81`          |
| Smart home hub      | [Home Assistant](https://www.home-assistant.io/) (Docker)                                                                                   | `:8123`        |
| Media server        | [Jellyfin](https://jellyfin.org/) with Intel QSV/VAAPI hardware transcoding                                                                 | `:8096`        |
| NAS / file sharing  | [Cockpit](https://cockpit-project.org/) + [45Drives `cockpit-file-sharing`](https://github.com/45Drives/cockpit-file-sharing) (Samba + NFS) | `:9090`        |
| Reverse proxy       | [Caddy](https://caddyserver.com/) with Tailscale `*.ts.net` certs                                                                           | `:80` / `:443` |
| Secrets vault       | [Vaultwarden](https://github.com/dani-garcia/vaultwarden)                                                                                   | `:8222`        |
| Auto-updates        | [Watchtower](https://containrrr.dev/watchtower/) (label-based opt-in)                                                                       | —              |
| Backups             | [Restic](https://restic.net/) cron to a local USB drive                                                                                     | —              |
| VPN                 | [Tailscale](https://tailscale.com/)                                                                                                         | —              |
| Dev runtime         | Node 24 LTS, Bun, pnpm, Docker CE, Homebrew (Linuxbrew)                                                                                     | —              |
| AI coding CLIs      | Claude Code, Codex, Gemini, Cursor Agent, OpenCode, Kimi                                                                                    | —              |

Plus 10 bonus GitHub tools cloned and built under `/opt/tools/` (Hindsight,
code-review-graph, Portless, claude-context, utoo, hermes-agent, OpenViking,
oh-my-opencode, oh-my-claudecode, claude-mem).

## Quick start

```bash
# 1. (optional) bake your SSH pubkey into the ISO — skip this for a public build
cp ~/.ssh/id_ed25519.pub secrets/authorized_keys

# 2. build the ISO (uses Docker)
make iso

# 3. flash to USB
diskutil list                                              # macOS — find your USB
diskutil unmountDisk /dev/diskN
sudo dd if=dist/homeos-debian-13.4-amd64.iso \
        of=/dev/rdiskN bs=4m status=progress
sync && diskutil eject /dev/diskN

# 4. boot the target box from USB. unattended install runs.
#    after reboot: ssh admin@<dhcp-ip>  (default password: homeos — forced change)
```

ARM64 build:

```bash
make ARCH=arm64 iso        # produces dist/homeos-debian-13.4-arm64.iso
```

## Public distro mode

By default HomeOS builds as a **public distro** — no SSH key baked in,
default credentials `admin` / `homeos`, password is **expired** so the
first SSH login forces a password change. After uploading your pubkey, run
`sudo homeos secure` to lock the admin password and disable password auth
permanently.

If you `cp ~/.ssh/id_ed25519.pub secrets/authorized_keys` before `make iso`,
your key is baked in and the install is private to you from the first boot.

## Day-2 operations — `homeos` CLI

```
homeos status                      # services, disks, containers, GPU, tailscale
homeos doctor                      # full smoke test (exits non-zero if any check fails)
homeos secure                      # lock admin password + disable SSH password auth
homeos config rerun-bootstrap      # re-run the Ansible playbook
sudo homeos config secrets set KEY=VAL  # write secrets.env (sourced by zsh)
homeos config secrets list / get
homeos config nas add /dev/sdc1    # mount + share a USB drive
homeos config nas list / remove
homeos config stack up jellyfin    # docker compose up -d on a stack
homeos config stack down/update/logs
homeos config net tailscale-up [--auth-key KEY]
homeos config net caddy-reload
homeos config backup target set /srv/nas/backups
homeos config backup run
homeos config cosmos on|off|status
homeos audit tail|search|show|replay|cosmos-events
```

Gated mutating CLI commands require `sudo`, write redacted public JSONL to
`/var/log/homeos-audit.jsonl`, and write root-only replay sidecars to
`/var/lib/homeos/audit-replay/` for 90 days. Use `homeos audit show <id_or_hash>`
to inspect an entry and `sudo homeos audit replay <id_or_hash>` to re-run its
stored argv through the AI gate.

Cosmos runs through `/var/run/cosmos-docker.sock`, a HomeOS Docker API shim
that forwards to Docker and records mutating UI actions as
`cosmos:<verb>:<resource>` / `BYPASS` audit entries without logging request
bodies.

## Repository layout

```
homeos/
├── Makefile                       # build orchestrator (iso, qemu-test, refresh-pins, clean)
├── README.md
├── docs/                          # detailed documentation (start here for anything beyond quick-start)
│   ├── INSTALL.md                 # step-by-step install walkthrough
│   ├── ARCHITECTURE.md            # how the three stages fit together
│   ├── BOOTSTRAP.md               # what each Ansible role does
│   ├── DAY2.md                    # full homeos CLI reference
│   ├── AI-GATE.md                 # AI review gate, audit log, Cosmos bypass events
│   ├── NAS.md                     # USB drive workflow + Cockpit/Samba/NFS
│   ├── SECURITY.md                # threat model + secure-mode flow
│   ├── HARDWARE.md                # supported hardware, GPU notes, networking
│   ├── DEVELOPMENT.md             # building from source, refreshing pins
│   ├── TROUBLESHOOTING.md         # what to check when first-boot stalls
│   └── FAQ.md
├── build/
│   ├── Dockerfile                 # debian:trixie-slim + xorriso toolchain
│   ├── download-base-iso.sh       # fetch + verify SHA256 of upstream Debian netinst
│   ├── repack-iso.sh              # xorriso pipeline — embed preseed + bootstrap
│   └── refresh-pins.sh            # update github_tools commit SHAs
├── preseed/
│   ├── preseed.cfg                # full unattended d-i answers
│   ├── grub.cfg                   # auto-boot, no menu, serial console enabled
│   └── isolinux.cfg               # legacy BIOS boot path
├── bootstrap/                     # Stage B — first-boot Ansible playbook
│   ├── install.yml                # top-level play (Ansible roles)
│   ├── requirements.yml           # ansible-galaxy collections
│   ├── vars/
│   │   ├── main.yml               # pinned versions, AI CLIs, github_tools, firewall
│   │   ├── stacks.yml             # docker-compose stack list
│   │   └── nas_disks.yml          # USB drives (filled in via `homeos config nas add`)
│   ├── files/                     # static files copied verbatim
│   └── roles/                     # Ansible roles — see docs/BOOTSTRAP.md
├── secrets/
│   └── authorized_keys            # YOUR ssh pubkey (gitignored). Empty = public build.
└── .github/workflows/
    └── build-iso.yml              # CI: builds amd64 + arm64 ISOs, publishes on tag
```

## Architecture in three stages

1. **Stage A — Custom preseed netinst ISO.** Built with `xorriso` from the
   upstream `debian-13.4.0-amd64-netinst.iso`. Fully unattended `debian-installer`
   answers. Boots straight to install, partitions disks, installs base +
   `openssh-server` + `ansible` + `git` + `curl`, drops `homeos-firstboot.service`,
   reboots. ISO ships with the entire `bootstrap/` directory copied verbatim
   under `/cdrom/homeos/`.

2. **Stage B — First-boot Ansible bootstrap.** Runs once on first boot, logs to
   `/var/log/homeos-bootstrap.log`, disables itself on success. Idempotent —
   safe to re-run with `homeos config rerun-bootstrap`. Pulls latest upstream
   for everything not pinned.

3. **Stage C — `homeos` config CLI.** Stays installed at `/usr/local/bin/homeos`.
   Day-2 ops live here: NAS drive add/remove, Docker stack lifecycle, secrets,
   Tailscale/Caddy/DDNS reconfig.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full details.

## Storage layout (default)

| Disk                | Layout                                                                       | Purpose                    |
| ------------------- | ---------------------------------------------------------------------------- | -------------------------- |
| `/dev/sda` (Disk 1) | `/boot` (1 GB ext4) + LVM `vg0/root` (rest, ext4)                            | OS + apps + container data |
| `/dev/sdb` (Disk 2) | LVM `vg1/swap` (16 GB) + `vg1/cache` (rest, attached as cache to `vg0/root`) | Swap + LVM cache tier      |
| USB drives          | per-drive UUID-pinned `systemd.mount` units under `/srv/nas/<label>/`        | NAS shares                 |

Cache attach happens in the `base` Ansible role only if `vg1/cache` exists.
USB drives are added at runtime via `homeos config nas add /dev/sdcN` — never
during install. See [docs/NAS.md](docs/NAS.md).

## Verification

After install completes and the bootstrap finishes, `homeos doctor` should
return all green:

- Node 24, Docker, Docker Compose, Homebrew installed
- Six AI CLIs callable (claude, codex, gemini, cursor-agent, opencode, kimi)
- Intel iGPU iHD driver loaded (VAAPI ready for Jellyfin)
- Cockpit, CasaOS, Tailscale services active
- HA, Jellyfin, CasaOS, Cockpit HTTP endpoints reachable
- All 10 `/opt/tools/` repos cloned and built

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) if any check fails.

## Building from source

Requires Docker (or OrbStack on macOS). Native arm64 macOS hosts can build
amd64 ISOs through Docker's QEMU layer.

```bash
make builder        # build the homeos-builder Docker image
make base-iso       # download + verify upstream Debian netinst
make iso            # repack with preseed + bootstrap, emit dist/*.iso + .sha256
make ARCH=arm64 iso # arm64 variant
make qemu-test      # boot the ISO in QEMU (reserved for final/orchestrated validation)
make clean          # nuke dist/ and qemu disk images
make refresh-pins   # print latest github_tools commit SHAs
make pin-tools      # write latest SHAs into bootstrap/vars/main.yml before tagging
make check-static   # shell/YAML/policy checks without building or booting an ISO
```

CI is intentionally tag/manual-only: `v*` tags and `workflow_dispatch` build both
architectures from committed pins, publish short-lived artifacts, and attach ISOs
plus `.sha256` files to tagged releases. It does not run on branch pushes or pull requests. See
[.github/workflows/build-iso.yml](.github/workflows/build-iso.yml).

Verify release artifacts after download:

```bash
sha256sum -c homeos-debian-13.4-amd64.iso.sha256
```

## Security

HomeOS is **opinionated about security but pragmatic about first boot**:

- Default password is `homeos`, **expired** at install — first SSH login is
  forced to change it. Document this clearly when sharing the ISO.
- Until you run `homeos secure`, password SSH is allowed (you need it to
  upload your first key). After `homeos secure`: key-only, password locked.
- Root login: never permitted.
- Default firewall: deny inbound, except the listed ports + the `tailscale0`
  interface fully trusted.
- Fail2ban watches `sshd`. Unattended security upgrades (Debian Security
  pocket only) run automatically.
- All Tailscale services use Tailscale-issued ACME-equivalent certificates —
  no public DNS or LetsEncrypt account needed.
- Cosmos uses the HomeOS Docker socket audit shim instead of mounting the host
  Docker socket directly. Other Docker-control UIs that require the host socket
  are documented as host-root-equivalent accepted risks.
- Gated commands write redacted public audit JSONL and root-only replay sidecars
  with a 90-day sidecar retention timer.
- Debian base ISOs are checked against `build/debian-base-isos.sha256` and
  upstream `SHA256SUMS`; release ISOs ship with `.sha256` verification files.

See [docs/SECURITY.md](docs/SECURITY.md) for the full threat model and
hardening checklist.

## Documentation

| Doc                                                | When to read                           |
| -------------------------------------------------- | -------------------------------------- |
| [docs/INSTALL.md](docs/INSTALL.md)                 | First time installing on real hardware |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)       | Understanding how it all fits together |
| [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md)             | Customizing what gets installed        |
| [docs/DAY2.md](docs/DAY2.md)                       | Full `homeos` CLI reference            |
| [docs/NAS.md](docs/NAS.md)                         | Adding/removing USB drives, Samba/NFS  |
| [docs/SECURITY.md](docs/SECURITY.md)               | Hardening + secrets management         |
| [docs/HARDWARE.md](docs/HARDWARE.md)               | Supported hardware, GPU, networking    |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)         | Building from source, contributing     |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | First-boot stalls, broken services     |
| [docs/FAQ.md](docs/FAQ.md)                         | Common questions                       |

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgments

Built on the work of:

- Debian Project (base distribution + preseed)
- IceWhale Tech (CasaOS)
- Home Assistant + Jellyfin + Vaultwarden communities
- 45Drives (cockpit-file-sharing)
- Tailscale, Caddy, Docker, NodeSource
- Anthropic, OpenAI, Google, Cursor, sst, Moonshot — for the AI CLIs
- Authors of the 10 bundled GitHub tools (see [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md))
