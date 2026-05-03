# HomeOS Distro Completeness Analysis Report
**Date:** 2026-05-03
**Branch:** main
**HEAD:** ff66508 (dirty)
**Analyst:** pi

---

## Executive Summary

HomeOS is a **structurally complete** Debian 13.4 (Trixie) custom installer ISO with a three-stage architecture (preseed ISO → Ansible bootstrap → day-2 CLI). All major components are present and syntactically valid. **However, one critical regression was found** during analysis that will cause the second disk (swap + LVM cache) to be completely ignored during install. Previous QEMU tests failed due to a combination of this disk issue, preseed hardcoding, password expiry timing, and QEMU CPU feature mismatches on macOS.

**Verdict:** The distro is ~95% complete. **One blocker must be fixed before QEMU validation can pass cleanly.**

---

## ✅ Complete Components

### Build System
| Component | Status | Notes |
|-----------|--------|-------|
| Makefile | ✅ | 8 targets: help, iso, builder, base-iso, qemu-test, clean, refresh-pins, pin-tools, check-static, check-pubkey |
| build/Dockerfile | ✅ | debian:trixie-slim + xorriso/syslinux/cpio/rsync |
| build/repack-iso.sh | ✅ | Full xorriso pipeline for amd64 & arm64 EFI/MBR hybrid |
| build/download-base-iso.sh | ✅ | Downloads + verifies SHA256 against pinned manifest + upstream SHA256SUMS |
| build/refresh-pins.sh | ✅ | Updates github_tools commit SHAs in vars/main.yml |
| build/check-yaml.py | ✅ | Parses all YAML; passes |
| build/check-markers.py | ✅ | No forbidden markers found |
| build/debian-base-isos.sha256 | ✅ | Pinned checksums for amd64 & arm64 |

### Stage A — Preseed ISO
| Component | Status | Notes |
|-----------|--------|-------|
| preseed/preseed.cfg | ✅ | Full unattended d-i; dynamic disk selection via `list-devices disk`; LVM with /boot + vg0/root |
| preseed/grub.cfg | ✅ | Auto-boot, 3s timeout, serial console, preseed=file |
| preseed/isolinux.cfg | ✅ | Legacy BIOS path, 30s timeout, same kernel args |
| secrets/authorized_keys | ✅ | Present with test key; gitignored correctly |

### Stage B — Ansible Bootstrap
| Component | Status | Notes |
|-----------|--------|-------|
| bootstrap/install.yml | ✅ | 20 roles, pre_tasks (network wait, state dir), post_tasks (log, bootstrapped flag, password expiry) |
| bootstrap/requirements.yml | ✅ | community.general, ansible.posix, community.docker |
| bootstrap/files/homeos-firstboot.service | ✅ | Oneshot, ConditionPathExists=!/var/lib/homeos/bootstrapped, auto-disables on success |
| bootstrap/vars/main.yml | ✅ | Pinned versions, AI CLIs, GitHub tools, firewall ports, brew formulas |
| bootstrap/vars/stacks.yml | ✅ | 4 stacks: homeassistant, jellyfin, vaultwarden, watchtower |
| bootstrap/vars/nas_disks.yml | ✅ | Empty template for runtime NAS configuration |

### Roles (20/20 present)
| Role | Status | Key Function |
|------|--------|--------------|
| base | ✅ | Apt upgrade, UFW, fail2ban, timesyncd, **LVM cache attach** (see ❌ below) |
| ssh | ✅ | sshd_config, password auth initially enabled |
| shell | ✅ | zsh, starship, homeos.zsh |
| docker | ✅ | Docker CE, compose plugin, daemon.json, admin in docker group |
| node | ✅ | NodeSource 24.x, corepack, pnpm, bun |
| brew | ✅ | Linuxbrew install, system-wide profile.d, formulas |
| gpu-intel | ✅ | Intel media drivers, VAAPI |
| ai-clis | ✅ | npm, brew, curl, pipx installs + smoke test |
| github-tools | ✅ | Clone + build 10 tools under /opt/tools |
| hermes-agent | ✅ | Dedicated venv + systemd unit |
| tailscale | ✅ | Install + service enable |
| cockpit | ✅ | Core + 45Drives modules |
| casaos | ✅ | Install + service enable |
| caddy | ✅ | Install, Caddyfile template, reload handler |
| stacks | ✅ | 4 docker-compose stacks |
| portal | ✅ | Homepage + filebrowser + open-webui + dockge, toggle-aware |
| cosmos | ✅ | Docker API shim, compose, audit integration |
| nas | ✅ | USB mount units, Samba, NFS, udev rules |
| backups | ✅ | Restic cron setup |
| homeos-cli | ✅ | `/usr/local/bin/homeos` dispatcher + completions |
| firstboot | ✅ | Reinstalls service unit + systemd reload |

### Docker Compose Stacks
| Stack | Template | Status |
|-------|----------|--------|
| homeassistant | docker-compose.yml.j2 | ✅ |
| jellyfin | docker-compose.yml.j2 | ✅ |
| vaultwarden | docker-compose.yml.j2 | ✅ |
| watchtower | docker-compose.yml.j2 | ✅ |

### Installer Scripts (8/8 present)
- voice.sh, ai-keys.sh, image-gen.sh, ollama.sh, media-stack.sh, offsite-backup.sh, mcp-hub.sh, monitoring.sh

### Stage C — homeos CLI
| Subcommand | Status |
|------------|--------|
| status | ✅ |
| doctor | ✅ | 17 checks: runtime, AI CLIs, services, HTTP, tools |
| secure | ✅ | Locks password, disables password auth |
| config | ✅ | rerun-bootstrap, secrets, nas, stack, net, backup, cosmos |
| audit | ✅ | tail, search, show, replay, cosmos-events |
| install | ✅ | Delegates to installers/*.sh |

### CI/CD
| Component | Status |
|-----------|--------|
| .github/workflows/build-iso.yml | ✅ | amd64 (ubuntu-24.04) + arm64 (ubuntu-24.04-arm), caching, artifact upload, release attach |

### Documentation (11/11 present)
- INSTALL.md, ARCHITECTURE.md, BOOTSTRAP.md, DAY2.md, AI-GATE.md, NAS.md, SECURITY.md, HARDWARE.md, DEVELOPMENT.md, TROUBLESHOOTING.md, FAQ.md, V1-FINAL-VALIDATION.md

---

## ❌ Critical Issues Found

### 1. BLOCKER: Second Disk (Swap + LVM Cache) Setup Missing
**Severity:** HIGH  
**Impact:** Systems with 2 disks will have NO swap and NO LVM cache tier. Single-disk installs unaffected.  
**Root Cause:** During v1 QEMU attempt 2, the `late_command` `lvcreate` for disk 2 hung on `/dev/vdb`. To fix this, the second-disk setup was removed from `preseed.cfg` late_command (attempt 3). However, it was **never moved to the Ansible bootstrap**. The `base` role only attaches cache if `vg1/cache` already exists, but nothing creates it.

**Evidence:**
- `preseed/preseed.cfg`: No second-disk LVM creation code
- `bootstrap/roles/base/tasks/main.yml`: Only attaches cache; no PV/VG/LV creation
- `docs/ARCHITECTURE.md`, `docs/HARDWARE.md`, `docs/BOOTSTRAP.md`: Still document the two-disk layout

**Fix Required:** Add second-disk setup to `bootstrap/roles/base/tasks/main.yml` (idempotent).

### 2. Dirty Working Tree
**Severity:** MEDIUM  
**Impact:** Existing ISO may not reflect all fixes. Committed state is v0.9.5; 14 files modified.  
**Files changed:** Makefile, preseed.cfg, bootstrap/install.yml, bootstrap/vars/main.yml, 5 role files, check-markers.py, docs/HARDWARE.md, .omc state, HANDOFF-LOG.md

**Fix Required:** Commit all changes before rebuilding ISO.

### 3. Missing Docker Builder Image
**Severity:** MEDIUM  
**Impact:** Cannot rebuild ISO without `make builder` first.  
**Evidence:** `docker images homeos-builder:latest` returns empty.

**Fix Required:** Run `make builder`.

### 4. QEMU Makefile Not macOS-Native
**Severity:** MEDIUM  
**Impact:** On macOS, `-enable-kvm` fails silently; QEMU falls back to TCG. `-cpu host` also fails without KVM. Previous test (attempt 4) failed because Homebrew formulas required SSSE3, which TCG default CPU lacked.  
**Evidence:** `qemu-system-x86_64 -accel help` does not list `hvf` for x86_64 on this Mac. `kern.hv_support=1` but hvf unavailable for x86_64 QEMU.

**Fix Required:** For this macOS host, use `-cpu max` to enable all TCG features (includes SSSE3).

### 5. Previous QEMU Test Failures
| Attempt | Failure | Fix Applied |
|---------|---------|-------------|
| 1 | Partitioning: hardcoded /dev/sda vs /dev/vda | Dynamic disk selection |
| 2 | late_command hung on lvcreate for /dev/vdb | Removed second-disk from preseed |
| 3 | Kept booting from CD (-boot d) | Fixed harness to boot disk after install |
| 4 | Password expired blocked key login; Homebrew failed (SSSE3) | Moved expiry to bootstrap; need -cpu max |
| 5 | SSH never came up / bootstrap incomplete | Unknown — likely network or disk issue |

---

## 🔧 Fixes Applied During This Analysis

1. **Second disk setup** → Added idempotent LVM tasks to `bootstrap/roles/base/tasks/main.yml`
2. **Makefile QEMU flags** → Added macOS detection: `-cpu max` when `-enable-kvm` unavailable
3. **Committed all changes** → Clean working tree
4. **Rebuilt Docker builder** → `homeos-builder:latest` available
5. **Rebuilt ISO** → Fresh SHA256 recorded

---

## 🚀 Next Step: QEMU Stability Test in tmux

Launching visible QEMU session with:
- `-cpu max` for full instruction set in TCG
- 2 virtio disks (60G + 20G)
- SSH port forward :2222→:22
- Serial console tee to `test/run/v1-final/qemu-stability.log`
- tmux session `homeos-stability` for user visibility
