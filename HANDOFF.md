# HomeOS — Historical Handoff Prompt (v0.3 → v0.6)

> Historical brief retained for background. `ROADMAP-TO-0.9.md` supersedes
> this file for v0.5-v0.9 execution policy, release scope, and validation
> gates. In particular, QEMU/full ISO validation is deferred to v1.0
> orchestrator-only.

---

## 0. Historical mission

This file originally drove the v0.3→v0.6 path. Current agents should use
`ROADMAP-TO-0.9.md` instead: v0.4.0 has shipped, v0.5.0 is the Cosmos
Docker socket shim release, v0.6.0 is audit replay, v0.7.0 is bootstrap
fixes, v0.8.0 is hardening, v0.9.0 is release-candidate polish, and
v1.0.0 owns final full ISO/QEMU validation.

---

## 1. Project background — what HomeOS is

HomeOS is a single-shot installable Debian 13.4 (Trixie) ISO for a headless
home server. Flash USB → boot → walk away → end with fully configured box
reachable only via SSH/Tailscale. No GUI ever attached.

The box runs simultaneously:
- CasaOS app dashboard
- Home Assistant hub
- Jellyfin with Intel QSV/VAAPI hardware transcoding
- Cockpit-managed NAS for USB drives (Samba + NFS via 45Drives module)
- Docker host
- Developer workstation (Node 24 LTS, Homebrew, every major AI coding CLI)
- Optional: Ollama, MCP hub, monitoring, media-stack, offsite backup,
  ComfyUI, voice (Whisper/Piper)

Two new pillars added in `v0.3.0`:
1. **AI Review Gate** — every mutating CLI command renders a diff and
   routes through an AI reviewer (claude / openai / openrouter / ollama /
   none). Warn-only — owner has final say. Audit log JSONL with 10-yr
   retention.
2. **Opt-in installer framework** — `homeos install <feat>` gates feature
   add-ons behind explicit consent + the AI gate. Flag-tracked at
   `/var/lib/homeos/installed.d/`.

---

## 2. Repo coordinates

- Path: `/Users/heitor/Developer/github.com/bloodf/homeos`
- Origin: `https://github.com/bloodf/homeos`
- Default branch: `main`
- Latest tag: `v0.3.0` (commit on `main` HEAD as of handoff)
- License: project-level (check `LICENSE` or owner)

---

## 3. Locked decisions (do not relitigate)

| Topic | Decision |
|---|---|
| Hostname | `homeos` |
| Admin user | `admin` (sudo NOPASSWD, SSH key when present) |
| Locale / TZ / KB | `en_US.UTF-8` / `America/Sao_Paulo` / `us` |
| Network | DHCP |
| Disk encryption | None (headless reboots without intervention) |
| Disk 1 | OS + apps, ext4 on LVM (`vg0/root`) |
| Disk 2 | LVM `vg1` → swap 16G + cache LV attached to `vg0/root` |
| NAS | USB-attached drives only, mounted under `/srv/nas/<label>` |
| NAS UI | Cockpit + 45Drives `cockpit-file-sharing` |
| Media | Jellyfin (Docker) + Intel QSV/VAAPI |
| GPU baseline | Modern Intel iGPU (Gen 9+) — `intel-media-va-driver-non-free` |
| Container layer | CasaOS + Docker CE |
| Smart-home | Home Assistant Container on Docker, port 8123 |
| Reverse proxy | Caddy with Tailscale `*.ts.net` certs (no public DNS) |
| VPN | Tailscale (binary baked, `tailscale up` runs post-install) |
| Auto-updates | Watchtower (security tag only, criticals opted out) |
| Vault | Vaultwarden behind Caddy |
| Backups | Restic to local USB on cron; offsite is opt-in installer |
| Runtime | Node 24 LTS + Homebrew (Linuxbrew) |
| AI CLIs | Claude / Codex / Gemini / Cursor / OpenCode / Kimi |
| Shell | zsh + oh-my-zsh + starship for `admin` |
| Repo strategy | Self-contained — bootstrap copied onto ISO at `/cdrom/homeos/` |
| Secrets | Manual via `homeos config secrets set …` after first SSH |
| Single user | No SSO, no multi-tenant |
| Connectivity | Always online assumption, tailnet-only forever |
| Pubkey on ISO | **Optional** — fallback to default password `homeos` (must change first login, expired-on-boot) |
| Initial SSH | `PasswordAuthentication yes` allowed; `homeos secure` locks it down later |
| AI gate default | `none` (warn-only stays opt-in via `homeos config gate set <p>`) |
| Cosmos | Alt portal, **bypass-warn** path through gate (Cosmos UI changes get logged, not blocked) |
| Audit retention | 10 years (520 weekly rotations via logrotate) |
| MCP hub | Opt-in installer; runs as root |

---

## 4. Three-stage architecture

**Stage A — Custom preseed netinst ISO**
Built with `xorriso` from `debian-13.4.0-amd64-netinst.iso`. Fully unattended
`debian-installer` answers in `preseed/preseed.cfg`. Boots straight to
install, partitions disks, installs base + `openssh-server` + `ansible` +
`git` + `curl`, drops `homeos-firstboot.service`, reboots. ISO ships with
optional `secrets/authorized_keys`, hostname, user creds, and the entire
`bootstrap/` directory copied verbatim under `/cdrom/homeos/`.

**Stage B — First-boot Ansible bootstrap**
Runs once on first boot via `homeos-firstboot.service`. Logs to
`/var/log/homeos-bootstrap.log`. Disables itself on success. Idempotent —
safe to re-run with `homeos config rerun-bootstrap`. Pulls latest upstream
for everything not pinned.

**Stage C — `homeos` config CLI**
Stays installed at `/usr/local/bin/homeos`. Day-2 ops: NAS, Docker stacks,
secrets, Tailscale/Caddy/DDNS, AI gate provider, audit log, opt-in
installers.

Build environment: `Makefile` orchestrates a `debian:trixie` Docker image
(`build/Dockerfile`) holding `xorriso`, `dosfstools`, `mtools`, `isolinux`.
Host OS-agnostic.

---

## 5. Repo file map (memorize this)

```
homeos/
  Makefile                           # builder, base-iso, iso, qemu-test, refresh-pins, clean, pin-tools
  README.md
  HANDOFF.md                         # this file
  HANDOFF-LOG.md                     # append-only progress log (create if missing)
  build/
    Dockerfile                       # debian:trixie + xorriso toolchain
    download-base-iso.sh             # fetch + verify SHA256 of upstream netinst
    repack-iso.sh                    # unpack netinst, inject preseed + bootstrap, repack hybrid
    refresh-pins.sh                  # GitHub tool SHA pinning (--write to mutate)
    cache/                           # cached netinst ISO (gitignored)
  preseed/
    preseed.cfg                      # d-i answers: pubkey-optional, default pw `homeos` (expired)
    grub.cfg                         # auto-boot, no menu, serial console
    isolinux.cfg                     # legacy BIOS boot
  secrets/
    authorized_keys                  # YOUR ssh pubkey (optional, gitignored or symlinked at build)
  bootstrap/
    install.yml                      # top-level Ansible play
    vars/
      main.yml                       # tool versions, GitHub tool commit pins, AI CLIs
      nas_disks.yml                  # USB drive UUIDs (filled by `homeos config nas add`)
      stacks.yml                     # docker-compose stack defs
    files/
      homeos-firstboot.service
      homeos.zsh                     # admin zsh aliases
      starship.toml
    installers/
      ai-keys.sh
      ollama.sh
      mcp-hub.sh
      monitoring.sh
      media-stack.sh
      offsite-backup.sh
      image-gen.sh
      voice.sh
    roles/
      base/         apt upgrade, sysctl, ufw (TCP+UDP split), fail2ban, lvm cache attach
      ssh/          hardened sshd_config — initial PasswordAuthentication yes
      shell/        zsh + oh-my-zsh + starship for admin
      docker/       docker-ce + buildx + compose
      node/         NodeSource Node 24 LTS + corepack + pnpm + bun
      brew/         Homebrew Linux for admin
      ai-clis/      claude/codex/gemini/cursor-agent/opencode/kimi
      github-tools/ 10 repos cloned + built, SHA-pinned
      gpu-intel/    intel-media-va-driver-non-free, /dev/dri perms
      tailscale/    tailscaled enabled (NOT auto-up)
      cockpit/      cockpit + cockpit-file-sharing (45Drives)
      casaos/       CasaOS pinned
      caddy/        reverse proxy w/ Tailscale certs + conf.d/ for installers
      stacks/       docker compose: HA, Jellyfin, Vaultwarden, Watchtower
      portal/       Homepage + Open WebUI + Dockge + Filebrowser (toggle)
      cosmos/       Cosmos Cloud (toggle, alt portal)
      hermes-agent/ Hermes agent dedicated role
      nas/          USB udev rules + systemd.mount + Samba/NFS exports
      backups/      Restic + cron to local USB
      homeos-cli/   `homeos` CLI + bash/zsh completions + audit log + gate
      firstboot/    systemd unit, self-disable on success
  docs/
    AI-GATE.md             # gate behavior contract (UPDATE per tag)
    ARCHITECTURE.md
    BOOTSTRAP.md
    DAY2.md
    DEVELOPMENT.md
    FAQ.md
    HARDWARE.md
    INSTALL-OPTIONALS.md   # installer catalog (UPDATE per installer change)
    INSTALL.md
    NAS.md
    PORTAL.md
    SECURITY.md
    TROUBLESHOOTING.md
  release-notes/
    vX.Y.Z.md              # source-of-truth release notes (create per tag)
  .github/
    workflows/
      build-iso.yml        # tag-trigger + manual only — DO NOT add push/PR triggers
  dist/                    # built ISOs (gitignored)
```

---

## 6. Operating principles (agent-agnostic)

You may be Claude Code, Cursor, Codex CLI, Gemini CLI, OpenCode, Aider,
Continue, or a custom runtime. Adapt these rules to the tools available
to you.

1. **Read before edit.** Read every file you mutate first. No blind writes.
2. **Plan, then act.** For multi-file change: write the plan into
   `HANDOFF-LOG.md` as a checklist, execute, tick off.
3. **Atomic commits.** One concern per commit. Conventional Commits
   prefix (`feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `build`,
   `chore`).
4. **Never self-attribute as AI.** No `coauthor trailer: Claude`, no
   `[bot emoji] tool-generated footer text` footers, no AI mentions in commits, tags, PR
   titles/bodies, release notes, or issue comments. Author as a human.
5. **CI workflows stay manual / tag-only.** Do **not** add `push:` or
   `pull_request:` triggers to any workflow. Project policy: E2E GitHub
   workflows are manual-trigger only (`workflow_dispatch` + `tags:
   ['v*']`).
6. **Verify before claiming done.** Per file:
   - shell: `bash -n <file>`
   - yaml: `yamllint <file>` if installed, else `python3 -c 'import
     yaml; yaml.safe_load(open("<file>"))'`
   - ansible: `ansible-playbook --syntax-check bootstrap/install.yml`
     when reachable
   - release gate: use `ROADMAP-TO-0.9.md` for current v0.5-v0.9
     static/targeted validation; reserve full QEMU smoke for v1.0
     orchestrator-only validation.
7. **No destructive ops without confirmation:**
   - `git push --force` (refused on `main`)
   - `git reset --hard` to upstream
   - tag deletion / overwriting
   - `rm -rf` outside `build/cache/`, `dist/`, `test/run/`
   - touching anything in user `$HOME` outside the repo
8. **Parallelize independent work.** Doc writing, role refactor, ISO
   build, QEMU test can fan out. Keep one orchestrator owning git state
   to prevent lock contention.
9. **Workers never touch git.** If your runtime spawns sub-workers, the
   orchestrator alone runs git. Workers stage files via PRs into a
   scratch dir or via patches, orchestrator applies + commits.
10. **Log everything.** After every non-trivial step append to
    `HANDOFF-LOG.md`: ISO-8601 timestamp + commit SHA + one-line summary.
    Final line on each tag: `RELEASE vX.Y.Z sha=<short> iso=<sha256>`.
11. **Auto-mode defaults.** No clarifying questions for routine choices.
    Pick a reasonable default, log it. Ask only on irreversible /
    destructive decisions.
12. **Memory-aware.** If your runtime has session memory (episodic,
    project notes), search it before re-deriving facts. If not, this
    file is your only context.
13. **Caveman-style commits forbidden.** Owner uses caveman tone in
    chat; commits/PRs/release-notes are normal English.

---

## 7. Code conventions

- **Bash:** `set -euo pipefail` at top of every script unless an
  intentional pipefail bypass is required (and documented inline).
  POSIX-ish where possible; allowed bashisms: arrays, `[[`, `${var//}`.
- **Ansible:** roles live under `bootstrap/roles/<name>/{tasks,
  templates,handlers,files,defaults,vars}/`. Idempotent. Tagged.
  No raw `shell:` if a module fits.
- **Templates:** Jinja2 `.j2`. Reverse proxy snippets go to
  `/etc/caddy/conf.d/<feat>.caddy`, imported by main `Caddyfile`.
- **Installers:** `bootstrap/installers/<feat>.sh` self-contained,
  honor `--reconfigure` flag, mark `/var/lib/homeos/installed.d/<feat>.installed`
  on success, exit non-zero on failure.
- **CLI subcommands:** add to `cmd_<area>()` in
  `bootstrap/roles/homeos-cli/files/homeos`, completion in
  `homeos.bash-completion` and `_homeos`.

---

## 8. Carryover open-item list (verify status before redoing)

Memory log indicates several were committed during the v0.3 push.
Confirm by reading source. Mark done in `HANDOFF-LOG.md` with the
commit SHA proving completion.

| # | Task | Acceptance |
|---|---|---|
| 6 | ISO build pubkey-optional + default password | `secrets/authorized_keys` may be empty; preseed sets pw `homeos` with `chage -d 0` (expired); `repack-iso.sh` does not abort if pubkey absent |
| 7 | `homeos secure` subcommand | `homeos secure` verifies admin can SSH with key, then sets `PasswordAuthentication no` + `passwd -l admin`; refuses if key login not proven |
| 8 | `ssh` role allows password initially | role default: `PasswordAuthentication yes`; `homeos secure` flips to `no` |
| 9 | UFW TCP/UDP split | `firewall_allow_tcp` and `firewall_allow_udp` lists exist; NFS UDP, mDNS, Samba UDP all open |
| 10 | Pin GitHub tool SHAs at build | `make pin-tools` runs `build/refresh-pins.sh --write` and rewrites `bootstrap/vars/main.yml` SHAs in place |
| 11 | Real `make builder` + `base-iso` + `iso` | `dist/homeos-debian-13.4-amd64.iso` exists, sha256 logged |
| 12 | QEMU smoke ISO end-to-end | full §10 protocol passes |

---

## 9. Roadmap — what each tag delivers

### `v0.4.0` — gate breadth + Cosmos audit visibility

Already gated (verify): rerun-bootstrap, portal:on, install,
secrets:set, nas:add/remove, stack:up/down/update, cosmos:on/off.

New for v0.4:
- **Cosmos bypass-warn path.** Cosmos talks to Docker socket directly
  today. Add an audit reader that reads Cosmos's own action log
  (Cosmos writes to `/opt/cosmos/cosmos-server.log` or equivalent —
  inspect at runtime) and replays each mutating event into
  `/var/log/homeos-audit.jsonl` with `cmd: "cosmos:<action>"` and
  `verdict: "BYPASS"`. Implement as systemd unit `homeos-cosmos-audit.service`
  + tail script.
- **Doc updates:**
  - `docs/AI-GATE.md` — Cosmos bypass-warn explained, no v0.4 open-items left.
  - `docs/DAY2.md` — `homeos audit cosmos-events` command if added.
- **CLI additions:**
  - `homeos audit cosmos-events` — prints last N Cosmos-origin entries.

Acceptance: stop a container from Cosmos UI → audit log shows entry
within 5s. CI green. QEMU smoke passes.

### `v0.5.0` — Cosmos Docker socket shim

Historical plan superseded by `ROADMAP-TO-0.9.md`: v0.5 replaces
bypass-warn with a proactive Python Docker socket shim.

Implemented release shape:

- Shim path: `bootstrap/roles/cosmos/files/homeos-cosmos-docker-shim`.
- Service: `homeos-cosmos-docker-shim.service`.
- Listen socket: `/var/run/cosmos-docker.sock`.
- Upstream socket: `/var/run/docker.sock`.
- Cosmos compose mounts `/var/run/cosmos-docker.sock:/var/run/docker.sock`.
- Mutating Docker API calls for containers/images/networks/volumes emit
  `cmd: "cosmos:<verb>:<resource>"`, `verdict: "BYPASS"`, and body
  hash/size/truncation metadata before forwarding.
- `homeos status` and `homeos config cosmos status` report shim state.

For v0.5-v0.9, do not use this historical handoff's QEMU-per-tag text;
QEMU/full ISO validation is deferred to v1.0 orchestrator-only.

### `v0.6.0` — `homeos audit replay <id>`

- Extend `audit_log()` to also write the original argv + env vars
  needed for replay to a sidecar JSON at
  `/var/lib/homeos/audit-replay/<diff_hash>.json` (mode 0600,
  root-only). Public JSONL line keeps the redacted summary; sidecar
  holds replay payload.
- `homeos audit replay <id_or_hash>`:
  - resolves id (line number) or hash to sidecar
  - re-runs the same intent through the gate (so the reviewer sees
    it again)
  - refuses if sidecar missing (entry too old / pruned)
  - writes a new audit entry with `cmd: "audit:replay:<orig_cmd>"`
- `homeos audit show <id_or_hash>` — prints full entry incl. sidecar
  (root-only for sidecar reveal).
- Sidecar retention: 90 days, pruned daily by
  `homeos-audit-prune.timer`.
- Doc: extend `docs/AI-GATE.md` with replay flow.

Acceptance: `homeos audit replay` re-applies a prior `secrets:set`
(with rotated key), entry appears, original entry preserved. QEMU
smoke passes.

After v0.6 tagged + released + smoked → mission complete. No further
roadmap milestones in scope.

---

## 10. Historical QEMU full smoke-test protocol

The protocol below is retained for background and for the later v1.0
orchestrator-only validation. For v0.5-v0.9, use the static/targeted
validation gates in `ROADMAP-TO-0.9.md` instead of this QEMU-per-tag text.

### 10.1 Inputs (random, throw-away)

```bash
mkdir -p test/run
cd test/run
ssh-keygen -t ed25519 -N '' -f id_test -C test@homeos
TEST_PUBKEY="$(cat id_test.pub)"
TEST_HOSTNAME="homeos-test-$RANDOM"
TEST_FAKE_KEY="sk-ant-test-$(openssl rand -hex 16)"
echo "TEST_HOSTNAME=$TEST_HOSTNAME TEST_FAKE_KEY=$TEST_FAKE_KEY" \
  >> ../../HANDOFF-LOG.md
```

### 10.2 Build the ISO

```bash
cd /Users/heitor/Developer/github.com/bloodf/homeos
echo "$TEST_PUBKEY" > secrets/authorized_keys      # for this run only
make builder        # build the xorriso Docker image
make base-iso       # download + verify upstream netinst
make pin-tools      # SHA-pin GitHub tools (refresh-pins --write)
make iso            # repack
sha256sum dist/homeos-debian-13.4-amd64.iso \
  | tee -a HANDOFF-LOG.md
```

If `make iso` fails, **diagnose root cause**, do not bypass safety
checks. Common failures:
- `xorriso` missing → rebuild builder image
- `secrets/authorized_keys` permission → ensure 0644
- Docker pulls 429 → retry with backoff
- `pin-tools` curl SIGPIPE → known historical bug; verify
  `set -o pipefail` removed from refresh-pins.sh

### 10.3 Boot in QEMU

```bash
cd test/run
qemu-img create -f qcow2 disk1.qcow2 60G
qemu-img create -f qcow2 disk2.qcow2 20G

# Linux host with KVM:
qemu-system-x86_64 \
  -name "$TEST_HOSTNAME" \
  -m 8192 -smp 4 -enable-kvm -cpu host \
  -cdrom ../../dist/homeos-debian-13.4-amd64.iso \
  -drive file=disk1.qcow2,if=virtio \
  -drive file=disk2.qcow2,if=virtio \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=n0 \
  -nographic -serial mon:stdio \
  -boot d > qemu.log 2>&1 &
QEMU_PID=$!
echo $QEMU_PID > qemu.pid
```

macOS host: drop `-enable-kvm -cpu host`, add `-accel hvf`.
Headless CI without virt extensions: drop accel — slower but works.
Boot phase typically 8–12 min on KVM, 25–40 min on TCG.

### 10.4 Verify — staged

```bash
SSH() { ssh -p 2222 -i id_test \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=5 \
  admin@localhost "$@"; }

# Stage A: install completes, machine reboots, sshd up. Up to 30 min.
for i in $(seq 1 180); do
  SSH "echo ok" 2>/dev/null && break
  sleep 10
done || { echo FAIL: SSH never came up; kill $QEMU_PID; exit 1; }

# Stage B: bootstrap completes
SSH 'until test -f /var/lib/homeos/bootstrapped; do
       sleep 30
       sudo tail -n2 /var/log/homeos-bootstrap.log
     done'

# Stage C: doctor passes
SSH 'homeos doctor' || { echo FAIL: doctor; exit 1; }

# Stage D: gate set + audited mutating command
SSH 'sudo homeos config gate set none && \
     HOMEOS_AUTO_APPLY=1 sudo homeos config secrets set \
       TEST_KEY='"$TEST_FAKE_KEY"' && \
     homeos audit tail -n 5 | grep -q secrets:set' \
  || { echo FAIL: gate audit; exit 1; }

# Stage E: opt-in installer dispatch (offline-safe)
SSH 'HOMEOS_AUTO_APPLY=1 sudo homeos install ai-keys --reconfigure </dev/null \
     || true; \
     test -f /var/lib/homeos/installed.d/ai-keys.installed' \
  || { echo FAIL: installer; exit 1; }

# Stage F: secure subcommand (must keep our key working)
SSH 'sudo homeos secure' \
  || { echo FAIL: secure; exit 1; }
SSH 'echo still-works' \
  || { echo FAIL: SSH lost after secure; exit 1; }

# Stage G: reboot, services healthy
SSH 'sudo systemctl reboot' || true
sleep 90
for i in $(seq 1 30); do
  SSH 'systemctl is-system-running' && break || sleep 10
done

SSH 'systemctl is-active docker tailscaled cockpit.socket' \
  || { echo FAIL: services after reboot; exit 1; }

SSH 'docker ps --format "{{.Names}}" | sort' | tee containers.txt
for required in homeassistant vaultwarden watchtower; do
  grep -q "^$required" containers.txt \
    || { echo FAIL: missing $required; exit 1; }
done

echo PASS
echo "QEMU smoke PASS commit=$(cd ../.. && git rev-parse --short HEAD) \
iso=$(sha256sum ../../dist/homeos-debian-13.4-amd64.iso | cut -d' ' -f1)" \
  >> ../../HANDOFF-LOG.md
```

### 10.5 Pass criteria

- SSH on `:2222` with `id_test` key, no password prompt.
- `/var/lib/homeos/bootstrapped` present.
- `homeos doctor` exits 0.
- Gate audit entry recorded for `secrets:set`.
- `ai-keys` installer flag file exists.
- `homeos secure` does not lock you out.
- After reboot: `systemctl is-system-running` returns `running` or
  `degraded` (degraded acceptable only if the only failure is
  `tailscaled-needs-up` — log the reason).
- Required containers running: `homeassistant`, `vaultwarden`,
  `watchtower`. `jellyfin` requires `/dev/dri` — skip if not in QEMU
  (TCG has no GPU passthrough).

Fail = do not tag. Investigate, fix, rebuild ISO, re-run. Log each
cycle in `HANDOFF-LOG.md`.

### 10.6 Teardown

```bash
kill $(cat qemu.pid) 2>/dev/null
cd ../..
rm -rf test/run/*
git checkout -- secrets/authorized_keys 2>/dev/null \
  || rm -f secrets/authorized_keys
```

---

## 11. Historical release ritual (superseded)

This historical per-tag ritual is superseded by `ROADMAP-TO-0.9.md` and
`FRESH-ORCHESTRATOR-HANDOFF.md`. For v0.5-v0.9, the orchestrator owns
commit, tag, push, GitHub release, and CI watching after static/targeted
validation. Do not run the §10 QEMU protocol for those milestones; reserve
it for v1.0 final validation.

---

## 12. Definition of done — v0.6

- All carryover items (§8) closed and proven by reading source +
  commit SHAs.
- `v0.4.0`, `v0.5.0`, `v0.6.0` tagged on `main`, pushed to GitHub,
  releases published with notes.
- Each tag passed pre-release QEMU smoke (logged) **and** post-release
  CI-ISO smoke (logged).
- `docs/AI-GATE.md` shows zero `open-item v0.4|v0.5|v0.6` markers.
- `docs/INSTALL-OPTIONALS.md` matches the actual installer set.
- `README.md` reflects current feature set.
- No `open-item`, `fix-marker`, `tripwire-marker` strings anywhere in `bootstrap/`, `docs/`,
  `Makefile`, `build/*.sh`, `preseed/` (binaries in `build/cache/`
  don't count).
- `HANDOFF-LOG.md` ends with `HANDOFF COMPLETE — v0.6.0,
  sha=<short>, iso=<sha256>`.

---

## 13. Quick reference

### Make targets

| Target | Purpose |
|---|---|
| `make builder` | Build the xorriso Docker image |
| `make base-iso` | Download + verify upstream netinst |
| `make pin-tools` | Run `refresh-pins.sh --write` to lock GitHub SHAs |
| `make iso` | Full repack → `dist/homeos-debian-13.4-amd64.iso` |
| `make qemu-test` | (if implemented) one-shot QEMU launch |
| `make clean` | Wipe `dist/` and intermediate build artifacts |

### homeos CLI surface

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

### Env switches

| Var | Effect |
|---|---|
| `HOMEOS_NO_REVIEW=1` | bypass gate (audit-logged as bypass) |
| `HOMEOS_AUTO_APPLY=1` | skip y/N apply prompt (used in scripts + QEMU smoke) |

### Critical files when debugging

| Path | What |
|---|---|
| `/var/log/homeos-bootstrap.log` | Stage B Ansible output |
| `/var/log/homeos-audit.jsonl` | append-only gate audit |
| `/var/lib/homeos/bootstrapped` | first-boot success marker |
| `/var/lib/homeos/installed.d/<feat>.installed` | installer flag |
| `/var/lib/homeos/ai-gate-provider` | current gate provider |
| `/var/lib/homeos/cosmos.enabled` | Cosmos toggle flag |
| `/etc/caddy/conf.d/*.caddy` | installer-added subdomains |
| `~admin/.config/homeos/secrets.env` | AI provider keys |

---

## 14. Troubleshooting playbook

| Symptom | Likely cause | Fix |
|---|---|---|
| `make iso` fails at `pin-tools` with curl 56 / SIGPIPE 141 | `set -o pipefail` aborts on awk early-exit | remove `pipefail` from `refresh-pins.sh` (already known-fixed; verify) |
| ISO boots but SSH refuses key | `secrets/authorized_keys` empty during build | rebuild with key, or use default password `homeos` (forced change on first login) |
| Bootstrap log shows `iHD` driver missing | non-Intel host or QEMU TCG | acceptable in QEMU; `gpu-intel` role logs warn |
| `homeos audit tail` empty after gated command | gate provider was `none` and `HOMEOS_NO_REVIEW=1` | check provider with `homeos config gate show` |
| Cosmos cannot reach Docker (v0.5+) | shim service not started | `systemctl status homeos-cosmos-docker-shim` |
| CI build-iso fails on cache restore | upstream netinst sha changed | rerun `make base-iso` locally, commit new SHA in `bootstrap/vars/main.yml` |
| QEMU stuck at "Performing post-installation tasks" | `late_command` hung on second disk | check `/dev/sdb` exists in QEMU args |

---

## 15. What you must NOT do

- Add `coauthor trailer: Claude` (or any AI tag) to commits.
- Add `push:` or `pull_request:` triggers to GitHub workflows.
- Force-push to `main` or any release tag.
- Delete or move existing tags.
- Skip the required validation gate for the release scope. For v0.5-v0.9 this means static/targeted validation from `ROADMAP-TO-0.9.md`; full QEMU smoke is v1.0 orchestrator-only.
- Use Cloudflare R2 for any storage decision (locked: Railway only
  if cloud storage ever needed).
- Use `.local` mDNS domains for local dev — use `localhost` + port.
- Leave work uncommitted between sessions.
- Touch `~/.claude`, `.omc/`, `.claude/`, or anything outside the
  repo working tree.

---

## 16. Start here

1. Create or append to `HANDOFF-LOG.md`:
   `<ISO timestamp> — handoff received, HEAD=<git rev-parse --short HEAD>`.
2. Then follow `ROADMAP-TO-0.9.md` and `FRESH-ORCHESTRATOR-HANDOFF.md` for
   current v0.5-v0.9 execution, validation, and release ownership.
