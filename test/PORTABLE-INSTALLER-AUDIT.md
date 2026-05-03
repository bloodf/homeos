# Portable Installer Audit Report

**Date:** 2026-05-03
**Scope:** `install/` directory — bootstrap.sh, homeos-install.sh, lib/_.sh, modules/_.sh

---

## Architecture

The portable installer is a modular bash framework with:

- `bootstrap.sh` — one-liner entrypoint that clones the repo and launches the installer
- `homeos-install.sh` — main orchestrator with CLI parsing, interactive menus, dry-run, and apply
- `lib/ui.sh` — ANSI UI primitives (header, menu, confirm, prompt, multi-select)
- `lib/distro.sh` — OS detection (/etc/os-release parsing)
- `lib/pkg.sh` — Package manager abstraction (apt/dnf)
- `lib/profiles.sh` — Profile-to-feature mapping and feature registry loader
- `lib/runner.sh` — Dependency resolution, dry-run/apply, state tracking, logging
- `lib/ansible.sh` — Bridge to existing bootstrap Ansible roles
- `modules/*.sh` — 10 feature modules: base, docker, cockpit, caddy, tailscale, casaos, stacks, ai-clis, backups, security, monitoring

---

## Issues Found

### 🔴 CRITICAL — `lib/pkg.sh` apt repo keyring bug

**File:** `lib/pkg.sh` line 48-55

```bash
local keyring="/usr/share/keyrings/${name}-archive-keyring.gpg"
mkdir -p /usr/share/keyrings
curl -fsSL "$PKG_REPO_KEY" | gpg --dearmor -o "$keyring"
```

**Problem:** `gpg --dearmor` may fail if gpg is not installed. The script never installs gnupg before this point. The `base` module installs gnupg but only via `pkg_install`, and other modules (docker, caddy) add repos BEFORE base runs if dependency ordering is wrong.

**Impact:** Docker/Caddy repo setup will silently fail on a minimal system.

**Fix:** Add `ensure_pkg gnupg` before any `gpg --dearmor` call, or make `pkg_repo_add` install gnupg as prerequisite.

---

### 🔴 CRITICAL — `modules/monitoring.sh` port collision

**File:** `modules/monitoring.sh` line 35-44

The monitoring compose exposes Prometheus on port 9090 and Grafana on 3000.
But Cockpit (in the cockpit module) also uses port 9090.

**Impact:** If both monitoring and cockpit are selected, Prometheus will fail to bind to 9090.

**Fix:** Change Prometheus to a different port (e.g., 9091) or use a reverse proxy.

---

### 🟡 HIGH — `homeos-install.sh` does not handle `--source` correctly in bootstrap flow

**File:** `homeos-install.sh` line 27-30

```bash
HI_SOURCE=""
```

When called from `bootstrap.sh`, it passes `--source "$HOMEOS_DIR"`, which is correct. But `ansible::source_dir()` in `lib/ansible.sh` has this fallback chain:

```bash
guess="${HI_DIR%/install}/bootstrap"
```

This assumes the install/ directory is inside the repo root. When the user runs `curl ... | sudo bash` (bootstrap.sh), it clones to `/opt/homeos`, so `HI_DIR` is `/opt/homeos/install`, and the guess becomes `/opt/homeos/bootstrap` — correct.

But if the user downloads the script manually and runs it from `~/Downloads/install/`, the guess becomes `~/Downloads/bootstrap`, which doesn't exist.

**Impact:** Ansible roles silently skipped when source dir not found.

**Fix:** Already handled by `--source` flag; document this better.

---

### 🟡 HIGH — `modules/casaos.sh` installs via curl pipe without checksum verification

**File:** `modules/casaos.sh` line 24

```bash
curl -fsSL https://get.casaos.io | bash
```

**Problem:** No checksum, no version pin. This is a supply-chain risk.

**Fix:** Document as accepted risk or vendor the installer script.

---

### 🟡 HIGH — `modules/ai-clis.sh` does nothing without Ansible

**File:** `modules/ai-clis.sh` line 15-22

```bash
apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role ai-clis
  else
    ui::warn "ai-clis: ansible role required; install ansible or pass --source"
    return 0
  fi
}
```

**Problem:** This module has NO standalone implementation. It ONLY works if Ansible is available AND the bootstrap source dir is found. On a fresh Debian VM with just the portable installer, this will silently skip.

**Impact:** AI CLIs won't be installed when using the portable installer without Ansible.

**Fix:** Add standalone npm/brew/curl installation logic (copy from bootstrap/roles/ai-clis/tasks/main.yml).

---

### 🟡 MEDIUM — `lib/runner.sh` dependency resolution max 32 passes

**File:** `lib/runner.sh` line 85-108

```bash
for ((pass=0; pass<32; pass++)); do
```

If there are >32 dependency hops (unlikely but possible), resolution silently stops.

**Fix:** Increase to 128 or use a proper queue-based topo sort.

---

### 🟡 MEDIUM — `modules/docker.sh` missing usermod for admin user

**File:** `modules/docker.sh`

The Docker module installs docker-ce but never adds the current user to the docker group. The Ansible role does this via `ansible.builtin.user: groups: docker`, but the standalone path doesn't.

**Impact:** User must manually `sudo usermod -aG docker $USER` after install.

**Fix:** Add `usermod -aG docker ${SUDO_USER:-$USER}` in standalone apply path.

---

### 🟡 MEDIUM — `modules/stacks.sh` requires Ansible, no standalone

**File:** `modules/stacks.sh` line 15-21

Same issue as ai-clis. No standalone compose deployment logic.

**Fix:** Add standalone docker compose up logic using templates from bootstrap/roles/stacks/templates/.

---

### 🟡 MEDIUM — `modules/backups.sh` missing state file creation

**File:** `modules/backups.sh`

The module installs restic but doesn't create `/var/lib/homeos/backup.env` or set up the cron schedule. The Ansible role handles this, but the standalone path just installs the package.

---

### 🟢 LOW — `lib/ui.sh` `ui::menu` lacks "back" option

**File:** `lib/ui.sh`

In interactive mode, once a user selects a mode and profile, they can't go back. A "back" option would improve UX.

---

### 🟢 LOW — `homeos-install.sh` `--yes` bypasses appliance confirmation

**File:** `homeos-install.sh` line 123-135

```bash
if [[ "$HI_INTERACTIVE" == "0" ]]; then
  if [[ "$HI_YES" != "1" || "$HI_CONFIRM_APPLIANCE" != "1" ]]; then
    echo "ERROR: appliance mode in non-interactive runs requires both --yes and --confirm-appliance"
    exit 2
  fi
```

This is correct, but the error message says "non-interactive runs requires both --yes and --confirm-appliance" but the condition checks `HI_YES != "1" || HI_CONFIRM_APPLIANCE != "1"`. If the user passes neither flag, the first condition `HI_YES != "1"` triggers and the error message is slightly misleading.

**Fix:** Clarify error message or split into two checks.

---

### 🟢 LOW — `bootstrap.sh` does not verify git clone success

**File:** `bootstrap.sh` line 42-46

```bash
git clone --quiet --depth 1 --branch "$HOMEOS_REF" "$HOMEOS_REPO" "$HOMEOS_DIR" \
  || git clone --quiet "$HOMEOS_REPO" "$HOMEOS_DIR"
```

If both clones fail (network issue, repo private), the script continues and tries to execute a non-existent installer.

**Fix:** Check clone success before proceeding.

---

## Testing Plan

1. Download Debian 13 (Trixie) netinst ISO
2. Boot in QEMU with a fresh disk
3. Run minimal install (no desktop, with SSH server)
4. Copy portable installer scripts into VM
5. Run `sudo ./homeos-install.sh --mode adopt --profile server --yes`
6. Verify:
   - All selected features install without errors
   - Services start correctly
   - `homeos doctor` passes (or documents QEMU limitations)
