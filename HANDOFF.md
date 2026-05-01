# HomeOS Handoff — Drive v0.3 → v0.6

You are inheriting the HomeOS project at tag `v0.3.0`. Mission: ship `v0.4.0`,
`v0.5.0`, and `v0.6.0` per the roadmap, close every open TODO, and prove the
ISO works end-to-end inside QEMU before each release. Stop only when `v0.6.0`
is tagged, pushed, released on GitHub, and a fresh QEMU smoke test of the
final ISO passes.

## Repo

- Path: `/Users/heitor/Developer/github.com/bloodf/homeos`
- Origin: `https://github.com/bloodf/homeos`
- Latest tag: `v0.3.0`
- Default branch: `main`

## Operating principles (agnostic — any framework)

You may be Claude Code, Cursor, Codex, Gemini, OpenCode, or a custom agent
runtime. Adapt these rules to your own tools:

1. **Plan, then act.** Read `docs/`, `bootstrap/`, `Makefile`, `preseed/`,
   `build/` before writing. Never edit a file you have not read.
2. **Atomic commits.** One concern per commit. Conventional commit prefix
   (`feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `build`).
3. **Never self-attribute as AI** in commits, tags, PRs, releases. No
   `Co-Authored-By: Claude`, no `🤖 Generated with` footer. Author as the
   user would.
4. **Never auto-trigger CI workflows you did not author.** GitHub workflows
   stay manual-trigger / tag-trigger. Don't add `push:` or `pull_request:`
   triggers unless explicitly listed in this handoff.
5. **Verify before claiming done.** `bash -n` every shell file you touch.
   `ansible-lint` or `yamllint` if installed. QEMU smoke before tagging.
6. **No destructive ops without confirmation:** `git push --force`,
   `git reset --hard` upstream, deleting tags, `rm -rf` outside `build/cache`,
   touching the user's home directory.
7. **Use sub-agents / parallel workers** when work is independent: doc
   writing, role refactor, ISO build, QEMU test can fan out. Keep one
   orchestrator owning git state.
8. **Logs.** Append progress to `HANDOFF-LOG.md` at the repo root after every
   non-trivial step. One line per event, ISO-8601 timestamp + commit SHA.
9. **Check memory before asking.** If your runtime has session memory
   (episodic, project notes), read it before re-deriving facts.
10. **Auto mode.** No clarifying questions for routine choices. Pick a
    reasonable default, log it in `HANDOFF-LOG.md`, move on. Ask only on
    irreversible / destructive decisions.

## Open work — close all of it

### Carryover TaskList (some may already be in commits — verify against
`git log --oneline` before redoing)

- [ ] `#6` ISO build pubkey-optional + default password fallback
- [ ] `#7` `homeos secure` subcommand (key-verify + sshd lockdown + passwd lock)
- [ ] `#8` `ssh` role allows `PasswordAuthentication yes` initially
- [ ] `#9` UFW rules split TCP/UDP (NFS/mDNS/Samba UDP gap)
- [ ] `#10` Pin GitHub tool SHAs at build via `make refresh-pins --write`
- [ ] `#11` Run real `make builder` + `make base-iso` + `make iso`, ensure
      `dist/homeos-debian-13.4-amd64.iso` exists
- [ ] `#12` QEMU smoke test the ISO end-to-end (see protocol below)

Verify each by reading the actual code. If already done, mark done in the
log and move on.

### Roadmap — must ship before v0.6

`v0.4.0` — extend the gate

- [ ] Add `homeos config nas add/remove` already gated → confirm test path
- [ ] Add `homeos config secrets set` already gated → confirm
- [ ] Add `homeos config stack up/down/update` already gated → confirm
- [ ] Add Cosmos bypass-warn path (Cosmos UI mutating containers via socket
      should warn-log to audit). Implementation: docker socket proxy in
      front of Cosmos with intercept that logs to `homeos-audit.jsonl`.
      Acceptable simpler v0.4: document the bypass + add `homeos audit
      cosmos-events` reader for Cosmos's own log.
- [ ] Doc updates: `docs/AI-GATE.md`, `docs/DAY2.md`.

`v0.5.0` — Cosmos Docker socket shim

- [ ] Build a tiny Go or Bash socket-activated proxy on
      `/var/run/cosmos-docker.sock` that forwards to the real Docker
      socket and emits an audit entry per `POST /containers/...`,
      `DELETE`, `PUT` (anything mutating).
- [ ] Cosmos compose mounts the shim, not the real socket.
- [ ] Test: stop a container from Cosmos UI → audit log gains an entry
      `{cmd: "cosmos:container.stop", ...}`.

`v0.6.0` — `homeos audit replay <id>`

- [ ] Extend `audit_log()` to also write the original argv to a sidecar
      file `/var/lib/homeos/audit-replay/<diff_hash>.json` (root-only,
      0600). The JSONL line keeps the public summary; the sidecar holds
      replay payload.
- [ ] `homeos audit replay <id_or_hash>` re-runs the same intent.
      Routes through the gate again. Refuses if sidecar missing.
- [ ] `homeos audit show <id>` prints full entry incl. sidecar.

After v0.6 is tagged, no further roadmap milestones in scope.

## QEMU full smoke-test protocol

Run before every tag push (`v0.4.0`, `v0.5.0`, `v0.6.0`). Random keys/configs
are fine — this is "does it boot, does SSH work, does bootstrap finish".

### Inputs (random, throw-away)

```bash
# in-repo workspace, gitignored
mkdir -p test/run
cd test/run
ssh-keygen -t ed25519 -N '' -f id_test -C test@homeos
TEST_PUBKEY="$(cat id_test.pub)"
TEST_HOSTNAME="homeos-test-$RANDOM"
TEST_API_FAKE_KEY="sk-ant-test-$(openssl rand -hex 16)"
```

### Build

```bash
make builder
make base-iso       # downloads + sha-checks the upstream netinst
echo "$TEST_PUBKEY" > ../../secrets/authorized_keys   # only for this test
make iso
ls -lh ../../dist/homeos-debian-13.4-amd64.iso        # must exist
```

### Boot

```bash
qemu-img create -f qcow2 disk1.qcow2 60G
qemu-img create -f qcow2 disk2.qcow2 20G

qemu-system-x86_64 \
  -m 8192 -smp 4 -enable-kvm \
  -cdrom ../../dist/homeos-debian-13.4-amd64.iso \
  -drive file=disk1.qcow2,if=virtio \
  -drive file=disk2.qcow2,if=virtio \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n0 \
  -nographic -serial mon:stdio \
  -boot d &
QEMU_PID=$!
```

If KVM unavailable (CI / non-Linux host), drop `-enable-kvm` — slower but
still works. macOS: use `-accel hvf` instead.

### Wait + verify

```bash
# Stage A: install completes, machine reboots, sshd up. Up to 30 min.
for i in {1..180}; do
  ssh -p 2222 -i id_test \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      admin@localhost "echo ok" 2>/dev/null && break
  sleep 10
done || { echo "SSH never came up"; kill $QEMU_PID; exit 1; }

# Stage B: bootstrap completes
ssh -p 2222 -i id_test admin@localhost \
  'until test -f /var/lib/homeos/bootstrapped; do sleep 30; \
   tail -n2 /var/log/homeos-bootstrap.log; done'

# Stage C: doctor passes
ssh -p 2222 -i id_test admin@localhost 'homeos doctor'

# Stage D: gate works
ssh -p 2222 -i id_test admin@localhost \
  "sudo homeos config gate set none && \
   HOMEOS_AUTO_APPLY=1 sudo homeos config secrets set TEST_KEY=$TEST_API_FAKE_KEY && \
   homeos audit tail -n 5"

# Stage E: installer works (offline-safe one)
ssh -p 2222 -i id_test admin@localhost \
  'HOMEOS_AUTO_APPLY=1 sudo homeos install ai-keys --reconfigure </dev/null || true'

# Stage F: secure subcommand
ssh -p 2222 -i id_test admin@localhost \
  'sudo homeos secure --dry-run 2>&1 || sudo homeos secure'

# Stage G: reboot, services healthy
ssh -p 2222 -i id_test admin@localhost 'sudo reboot' || true
sleep 60
for i in {1..30}; do
  ssh -p 2222 -i id_test admin@localhost 'systemctl is-system-running' \
    && break || sleep 10
done
ssh -p 2222 -i id_test admin@localhost \
  'systemctl is-active docker tailscaled cockpit.socket && \
   docker ps --format "{{.Names}}" | sort'
```

Pass criteria:

- SSH reachable on `:2222` with `id_test` key, no password prompt.
- `/var/lib/homeos/bootstrapped` exists.
- `homeos doctor` exits 0.
- Gate audit entry recorded for the `secrets:set`.
- `systemctl is-system-running` returns `running` or `degraded` (degraded
  acceptable if Tailscale not authed — log the reason).
- Required containers running: at minimum `homeassistant`, `vaultwarden`,
  `watchtower`. `jellyfin` requires `/dev/dri` — skip if not in QEMU.

Fail = do not tag. Investigate, fix, rebuild ISO, re-run. Log each cycle in
`HANDOFF-LOG.md`.

### Teardown

```bash
kill $QEMU_PID 2>/dev/null
rm -rf test/run/*
git checkout -- secrets/authorized_keys      # restore real / empty pubkey
```

## Release ritual (per tag)

```bash
# pre-flight
git status -s         # must be clean
bash -n bootstrap/roles/homeos-cli/files/homeos
make iso              # rebuild from scratch

# QEMU smoke (above)

# tag + push
git tag -a vX.Y.Z -m "vX.Y.Z — <one-line summary>

<detailed notes>"
git push origin main
git push origin vX.Y.Z

# GitHub release (CI workflow build-iso.yml triggers on the tag and
# attaches ISOs; you create the release notes)
gh release create vX.Y.Z --title "vX.Y.Z — <summary>" \
  --notes-file release-notes/vX.Y.Z.md
```

`release-notes/vX.Y.Z.md` is the source of truth — write it under git, not
ad-hoc in the GitHub UI.

## Definition of done — v0.6

- All carryover tasks closed (verified by reading source, not by trusting
  prior logs).
- `v0.4.0`, `v0.5.0`, `v0.6.0` tagged + pushed + GitHub releases live.
- Each release passed QEMU smoke (logged in `HANDOFF-LOG.md` with timestamp,
  commit SHA, ISO sha256).
- `docs/AI-GATE.md` shows no `TODO v0.4|v0.5|v0.6` markers.
- `docs/INSTALL-OPTIONALS.md` matches actual installer set.
- `README.md` reflects current feature set.
- No `TODO`, `FIXME`, `XXX` strings in `bootstrap/`, `docs/`, `Makefile`,
  `build/`, `preseed/` (except inside `build/cache/` which holds upstream
  binaries).

When the v0.6 release is live and the final QEMU smoke passes, append
`HANDOFF COMPLETE — vX.Y.Z, sha=<hash>, iso=<sha256>` to `HANDOFF-LOG.md`
and stop.

## Quick reference

| File | Purpose |
|---|---|
| `Makefile` | `make builder \| base-iso \| iso \| qemu-test \| refresh-pins` |
| `preseed/preseed.cfg` | d-i answers — pubkey-optional, default pw `homeos` |
| `bootstrap/install.yml` | Top-level Ansible play |
| `bootstrap/roles/homeos-cli/files/homeos` | Day-2 CLI + AI gate |
| `bootstrap/installers/*.sh` | Opt-in installers |
| `docs/AI-GATE.md` | Gate behavior contract |
| `docs/INSTALL-OPTIONALS.md` | Installer catalog |
| `docs/DAY2.md` | Day-2 ops walkthrough |
| `.github/workflows/build-iso.yml` | Tag-trigger ISO build (manual + tags only — DO NOT add push/PR triggers) |

Good luck. Don't stop until v0.6 is on GitHub and a freshly built ISO boots
clean in QEMU.
