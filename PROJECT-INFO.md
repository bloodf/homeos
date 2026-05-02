# HomeOS — Project Info & State of the Project

> Living document for any agent (or human) joining the project. Captures
> what HomeOS is, every release shipped, every decision locked, every
> file that exists, and where the work currently stands. Pair with
> `HANDOFF.md` and `ROADMAP-TO-0.9.md` for historical release context.

Last updated: 2026-05-02 — after tag `v0.9.0`.

---

## 1. One-liner

HomeOS is a single-shot installable Debian 13.4 (Trixie) ISO that turns
a headless x86_64 home server into a self-hosted everything-box (CasaOS,
Home Assistant, Jellyfin w/ Intel QSV, Cockpit-managed NAS, Docker host,
AI dev workstation) with an **AI Review Gate** auditing every mutating
config change.

Flash USB → boot → walk away → SSH-in over Tailscale.

---

## 2. Why it exists

- One USB flash + walk away. No keyboard or screen on the server.
- Reproducible — the whole config is in git, re-flashable on hardware
  changes.
- Owner stays in control via SSH/Tailscale; AI advises but never
  silently mutates.
- Combines media server + smart-home hub + NAS + dev box in one
  machine, since most home labs run all four anyway.

---

## 3. Architecture (three stages)

| Stage | What | Where |
|---|---|---|
| A | Custom preseed netinst ISO (xorriso repack) | `build/`, `preseed/` |
| B | First-boot Ansible bootstrap, self-disabling | `bootstrap/` |
| C | `homeos` day-2 CLI + AI gate + audit log | `bootstrap/roles/homeos-cli/` |

Build environment is a `debian:trixie` Docker image — host OS doesn't
matter. `Makefile` orchestrates everything: `make builder`, `make
base-iso`, `make pin-tools`, `make iso`.

---

## 4. Releases shipped

### v0.1.0 — foundation

- Custom Debian 13.4 netinst ISO via xorriso repack.
- Preseed full unattended install (en_US.UTF-8, America/Sao_Paulo, us
  keyboard, DHCP, LVM on `vg0/root` + swap/cache on `vg1`).
- First-boot `homeos-firstboot.service` runs Ansible play.
- Roles: base, ssh, shell, docker, node, brew, ai-clis, github-tools,
  gpu-intel, tailscale, cockpit, casaos, caddy, stacks, nas, backups,
  homeos-cli, firstboot.
- AI CLIs preinstalled: Claude Code, Codex, Gemini, Cursor Agent,
  OpenCode, Kimi.
- 10 GitHub tools cloned + built, SHA-pinnable.
- Stacks: Home Assistant, Jellyfin (w/ `/dev/dri` passthrough),
  Vaultwarden, Watchtower.
- Cockpit + 45Drives `cockpit-file-sharing` for NAS UI.
- Caddy reverse proxy via Tailscale `*.ts.net` certs.
- Tag + GitHub release live.

### v0.2.0 — portals

- **HomeOS Portal** (toggle): Homepage + Open WebUI + Dockge +
  Filebrowser. Toggle via `homeos config portal on/off`.
- **Cosmos Cloud** alt portal (toggle): `homeos config cosmos
  on/off`. Behind Caddy on port 4444. First-run admin setup in browser.
- Hermes-agent dedicated role.
- Comprehensive docs: `INSTALL.md`, `ARCHITECTURE.md`, `BOOTSTRAP.md`,
  `DAY2.md`, `NAS.md`, `PORTAL.md`, `HARDWARE.md`, `SECURITY.md`,
  `TROUBLESHOOTING.md`, `FAQ.md`, `DEVELOPMENT.md`.
- CI workflow `build-iso.yml` (manual + tag triggers only — no
  push/PR triggers per project policy).
- Public-distro mode: ISO build pubkey-optional, default password
  `homeos` (expired-on-first-login).
- Tag + GitHub release live.

### v0.3.0 — AI Review Gate + Opt-in Installers

Two new pillars.

**Pillar 1 — AI Review Gate**

Every mutating CLI command renders a diff and routes through an AI
reviewer (`claude` / `openai` / `openrouter` / `ollama` / `none`)
before apply. Warn-only — owner has final say. Audit log JSONL
appended to `/var/log/homeos-audit.jsonl`, rotated weekly via
`logrotate`, retained 10 years (520 weeks).

Gated commands:
- `homeos config rerun-bootstrap`
- `homeos config portal on`
- `homeos install <anything>`
- `homeos config secrets set` (value redacted from diff, only length
  disclosed)
- `homeos config nas add/remove`
- `homeos config stack up/down/update`
- `homeos config cosmos on/off`

Provider:
- `sudo homeos config gate set <provider>` (stored at
  `/var/lib/homeos/ai-gate-provider`)
- `homeos config gate show`

Bypass / auto-apply:
- `HOMEOS_NO_REVIEW=1` — bypass gate, still audit-logged as bypass.
- `HOMEOS_AUTO_APPLY=1` — skip y/N prompt (script-friendly).

Audit:
- `homeos audit tail [-n N]` — last N entries (default 20)
- `homeos audit search <pattern>`

Audit format:
```json
{"ts":"...", "cmd":"portal:on", "user":"admin",
 "verdict":"APPROVE|WARN: …|REJECT: …",
 "choice":"apply|abort|bypass", "diff_hash":"<sha256-12>"}
```

**Pillar 2 — Opt-in installer framework**

```bash
homeos install --list
sudo homeos install <feature>
sudo homeos install <feature> --reconfigure
```

State at `/var/lib/homeos/installed.d/<feat>.installed`. Drop-in
installers at `/opt/homeos/bootstrap/installers/*.sh`.

Shipped installers:

| Feature | Adds |
|---|---|
| `ai-keys` | Wizard for ANTHROPIC / OPENAI / GOOGLE / CURSOR / OPENROUTER / MOONSHOT / GROQ keys → `secrets.env` |
| `ollama` | Ollama + qwen3:7b default, prompts GPU type, refuses naive CPU |
| `mcp-hub` | Official MCP servers + `mcp.json` for claude/codex/cursor/opencode |
| `monitoring` | Uptime Kuma + Scrutiny (disk SMART) + weekly Trivy scan |
| `media-stack` | Sonarr / Radarr / Prowlarr / Bazarr / qBittorrent → Jellyfin |
| `offsite-backup` | Restic to B2 / Storj / Hetzner SB / S3 / rclone — daily 03:30 BRT |
| `image-gen` | ComfyUI (NVIDIA-only, refuses without GPU) |
| `voice` | Whisper + Piper Wyoming → HA voice assist |

Docs: `docs/AI-GATE.md`, `docs/INSTALL-OPTIONALS.md`.

Tag + GitHub release live.

---

## 5. Locked decisions (do not relitigate)

| Topic | Decision |
|---|---|
| Hostname | `homeos` |
| Admin user | `admin` (sudo NOPASSWD; SSH key when present) |
| Locale / TZ / KB | `en_US.UTF-8` / `America/Sao_Paulo` / `us` |
| Network | DHCP |
| Disk encryption | None (headless reboots without intervention) |
| Disk 1 | OS + apps, ext4 on LVM `vg0/root` |
| Disk 2 | LVM `vg1` → swap 16G + cache LV attached to `vg0/root` |
| NAS storage | USB-attached drives only, mounted at `/srv/nas/<label>` |
| NAS UI | Cockpit + 45Drives `cockpit-file-sharing` (Samba + NFS) |
| Media server | Jellyfin (Docker) + Intel QSV/VAAPI |
| GPU baseline | Modern Intel iGPU (Gen 9+); `intel-media-va-driver-non-free` |
| Container layer | CasaOS + Docker CE |
| Smart-home | Home Assistant Container, port 8123 |
| Reverse proxy | Caddy with Tailscale `*.ts.net` certs (no public DNS) |
| VPN | Tailscale (binary baked, `tailscale up` post-install) |
| Auto-updates | Watchtower (security tag only; criticals opt out) |
| Vault | Vaultwarden behind Caddy |
| Backups | Restic to local USB on cron; offsite is opt-in installer |
| Runtime | Node 24 LTS + Homebrew (Linuxbrew) |
| AI CLIs | Claude / Codex / Gemini / Cursor / OpenCode / Kimi |
| Shell | zsh + oh-my-zsh + starship for `admin` |
| Repo strategy | Self-contained — bootstrap copied onto ISO at `/cdrom/homeos/` |
| Secrets handling | Manual via `homeos config secrets set …` after first SSH |
| Single user model | No SSO, no multi-tenant |
| Connectivity | Always online, tailnet-only forever |
| Pubkey on ISO | **Optional** — fallback default password `homeos`, forced change on first login |
| Initial SSH | Password auth allowed; `homeos secure` locks down later |
| AI gate default | `none` (warn-only stays opt-in) |
| Cosmos vs gate | Bypass-warn (Cosmos UI changes audit-logged, not blocked) |
| Audit retention | 10 years (520 weekly rotations via logrotate) |
| MCP hub | Opt-in installer; runs as root |
| Hardware UPS | Out of scope |
| Router DNS | Untouched |
| Cloud storage | Railway only (no Cloudflare R2) |
| CI triggers | Manual `workflow_dispatch` + `tags: ['v*']` ONLY (never push/PR) |

---

## 6. Repo file map (ground truth)

```
homeos/
  Makefile                           # builder | base-iso | iso | qemu-test | refresh-pins | clean | pin-tools
  README.md
  HANDOFF.md                         # mission brief v0.4 → v0.6
  PROJECT-INFO.md                    # this file
  HANDOFF-LOG.md                     # append-only progress log (created on first handoff entry)
  build/
    Dockerfile                       # debian:trixie + xorriso toolchain (syslinux-utils removed — not in trixie)
    download-base-iso.sh             # fetch + verify SHA256 of upstream netinst
    repack-iso.sh                    # unpack netinst → inject preseed + bootstrap → repack hybrid (pubkey-optional)
    refresh-pins.sh                  # GitHub tool SHA pinning (--write to mutate; pipefail disabled — SIGPIPE bug fixed)
    cache/                           # cached netinst ISO (gitignored)
  preseed/
    preseed.cfg                      # d-i answers; pubkey-optional, default pw `homeos` (chage -d 0)
    grub.cfg                         # auto-boot, no menu, serial console
    isolinux.cfg                     # legacy BIOS boot
  secrets/
    authorized_keys                  # YOUR ssh pubkey (optional; gitignored or symlinked at build)
  bootstrap/
    install.yml                      # top-level Ansible play
    vars/
      main.yml                       # tool versions, GitHub tool commit pins, AI CLIs
      nas_disks.yml                  # USB drive UUIDs (filled by `homeos config nas add`)
      stacks.yml                     # docker-compose stack defs
    files/
      homeos-firstboot.service
      homeos.zsh
      starship.toml
    installers/
      ai-keys.sh
      image-gen.sh
      mcp-hub.sh
      media-stack.sh
      monitoring.sh
      offsite-backup.sh
      ollama.sh
      voice.sh
    roles/
      ai-clis/      claude / codex / gemini / cursor-agent / opencode / kimi
      backups/      restic + cron to local USB
      base/         apt upgrade, sysctl, ufw (TCP+UDP split), fail2ban, lvm cache attach
      brew/         Homebrew Linux for admin
      caddy/        reverse proxy + Tailscale certs + conf.d/ for installers
      casaos/       CasaOS pinned
      cockpit/      cockpit + cockpit-file-sharing (45Drives)
      cosmos/       Cosmos Cloud (toggle)
      docker/       docker-ce + buildx + compose
      firstboot/    systemd unit, self-disable on success
      github-tools/ 10 repos cloned + built, SHA-pinned
      gpu-intel/    intel-media-va-driver-non-free, /dev/dri perms
      hermes-agent/ Hermes agent dedicated role
      homeos-cli/   `homeos` CLI + completions + audit log + gate + secure subcommand
      nas/          udev rules + systemd.mount + Samba/NFS exports
      node/         NodeSource Node 24 LTS + corepack + pnpm + bun
      portal/       Homepage + Open WebUI + Dockge + Filebrowser
      shell/        zsh + oh-my-zsh + starship
      ssh/          hardened sshd_config (PasswordAuthentication yes initially)
      stacks/       docker compose: HA, Jellyfin, Vaultwarden, Watchtower
      tailscale/    tailscaled enabled (does NOT auto-up)
  docs/
    AI-GATE.md             # gate behavior contract
    ARCHITECTURE.md
    BOOTSTRAP.md
    DAY2.md
    DEVELOPMENT.md
    FAQ.md
    HARDWARE.md
    INSTALL-OPTIONALS.md   # installer catalog
    INSTALL.md
    NAS.md
    PORTAL.md
    SECURITY.md
    TROUBLESHOOTING.md
  release-notes/           # source-of-truth release notes per tag (create on next release)
  .github/
    workflows/
      build-iso.yml        # tag + manual ONLY
  dist/                    # built ISOs (gitignored)
```

---

## 7. CLI surface today

```
homeos status | doctor | secure | audit tail|search
homeos config rerun-bootstrap
homeos config secrets set|get|list <KEY>
homeos config nas list|add|remove
homeos config stack up|down|update|logs <name>
homeos config net tailscale-up|caddy-reload
homeos config backup target|run
homeos config portal on|off|status
homeos config cosmos on|off|status
homeos config gate set <claude|openai|openrouter|ollama|none>
homeos config gate show
homeos install --list
homeos install <feature> [--reconfigure]
```

Bash + zsh completion shipped.

Env switches:

| Var | Effect |
|---|---|
| `HOMEOS_NO_REVIEW=1` | bypass gate (audit-logged as bypass) |
| `HOMEOS_AUTO_APPLY=1` | skip y/N apply prompt |

---

## 8. Critical runtime paths

| Path | What |
|---|---|
| `/var/log/homeos-bootstrap.log` | Stage B Ansible output |
| `/var/log/homeos-audit.jsonl` | append-only gate audit (10-yr retention) |
| `/var/lib/homeos/bootstrapped` | first-boot success marker |
| `/var/lib/homeos/installed.d/<feat>.installed` | installer flag |
| `/var/lib/homeos/ai-gate-provider` | current gate provider |
| `/var/lib/homeos/cosmos.enabled` | Cosmos toggle flag |
| `/var/lib/homeos/portal.enabled` | Portal toggle flag |
| `/etc/caddy/conf.d/*.caddy` | installer-added subdomains |
| `~admin/.config/homeos/secrets.env` | AI provider keys |
| `/opt/homeos/bootstrap/` | full bootstrap copy on the box |
| `/opt/stacks/<name>/docker-compose.yml` | stack defs |
| `/srv/nas/<label>` | mounted USB NAS drives |

---

## 9. Notable bugs already fixed (do not redo)

- `refresh-pins.sh` SIGPIPE 141 with `set -o pipefail` + awk early-exit
  → pipefail removed in pin-tools script.
- `Dockerfile` referenced `syslinux-utils` which is missing on
  `debian:trixie-slim` → removed; build green.
- `repack-iso.sh` unconditionally copied `secrets/authorized_keys`
  → made conditional so public builds work pubkey-less.
- `preseed.cfg` admin password was locked (`!`) blocking pubkey-less
  boot → set to `homeos` with `chage -d 0` (forced change on first
  login).
- `ssh` role `PasswordAuthentication no` blocked initial pw login
  → changed to `yes`; `homeos secure` flips back to `no` after key
  proven.
- UFW rules conflated TCP/UDP → split into `firewall_allow_tcp` +
  `firewall_allow_udp`; NFS UDP, mDNS, Samba UDP all open.
- CI `build-iso.yml` once had `push:` triggers — removed; now
  `workflow_dispatch` + `tags: ['v*']` only.

---

## 10. What's next — see `ROADMAP-TO-0.9.md`

Current release path:

- `v0.4.0` shipped the initial Cosmos bypass-warn audit reader.
- `v0.5.0` ships the proactive Cosmos Docker socket shim release.
- `v0.6.0` adds `homeos audit replay <id>` and sidecar replay payloads.
- `v0.7.0` is the bootstrap-fixes milestone.
- `v0.8.0` hardens security, supply-chain, docs, and CI.
- `v0.9.0` is release-candidate polish.
- `v1.0.0` is reserved for final full ISO/QEMU validation.

`ROADMAP-TO-0.9.md` is authoritative for v0.5-v0.9 scope and supersedes
older `HANDOFF.md` QEMU-per-tag guidance for those milestones.

---

## 11. Conventions binding any contributor

- Conventional Commits (`feat`, `fix`, `refactor`, `docs`, `test`,
  `ci`, `build`, `chore`).
- Atomic commits — one concern per commit.
- Never self-attribute as AI in commits / tags / PRs / release notes.
- Read every file before you edit it.
- `bash -n` every shell file you touch.
- No `push:` / `pull_request:` triggers in any workflow.
- No force-push to `main` or release tags.
- Workers don't touch git — orchestrator owns git state.
- Log significant steps to `HANDOFF-LOG.md`.

---

## 12. Glossary

- **Stage A** — preseed netinst ISO build (Docker + xorriso).
- **Stage B** — Ansible first-boot bootstrap (self-disabling).
- **Stage C** — `homeos` CLI day-2 ops surface.
- **Gate** — AI Review Gate; warn-only review of mutating commands.
- **BYPASS** — gate skipped via `HOMEOS_NO_REVIEW=1`; still
  audit-logged.
- **Bypass-warn** — v0.4 mode where Cosmos UI mutates Docker directly
  and HomeOS audited post-hoc rather than blocking.
- **Cosmos Docker socket shim** — v0.5 mode where Cosmos mounts
  `/var/run/cosmos-docker.sock`; the shim audits mutating Docker API
  calls before forwarding them to the real Docker socket.
- **Audit** — append-only JSONL of every mutating intent + verdict +
  choice + diff_hash.
- **Installer** — opt-in feature add-on under
  `bootstrap/installers/<feat>.sh`.
- **Toggle** — flag-file at `/var/lib/homeos/<feat>.enabled` plus
  systemd/compose lifecycle.

## Current CLI surface additions

The day-2 `homeos` CLI includes guided and diagnostic top-level commands: `init`, `upgrade`, `log`, and `diag`, alongside existing `status`, `doctor`, `secure`, `config`, `install`, and `audit` commands. Stack updates record digest snapshots, backups can be verified with `homeos config backup verify`, and firstboot failures are surfaced via `/var/lib/homeos/bootstrap-failed`.
