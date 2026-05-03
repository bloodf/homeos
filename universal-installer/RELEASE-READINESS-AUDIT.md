# HomeOS Universal Installer — Release Readiness Audit

**Date:** 2026-05-03
**Auditor:** PM + PO + CTO + CEO perspectives
**Target Release:** v1.0.0

---

## 1. PRODUCT MANAGER (PM) — Feature Completeness & UX

### ✅ What's Working

- [x] Single script installer for Debian/Ubuntu and Fedora/RHEL
- [x] Config file support with `--config` flag
- [x] Interactive and unattended modes
- [x] Minimal and full installation modes
- [x] Component selection (15 togglable components)
- [x] Built-in `homeos` CLI (status, doctor, update)
- [x] Docker CE + Compose installation
- [x] Node.js 24 + pnpm + Bun
- [x] Home Assistant, Jellyfin, Vaultwarden compose stacks
- [x] Prometheus + Grafana monitoring stack
- [x] Tailscale VPN integration
- [x] Caddy reverse proxy
- [x] Cockpit + 45Drives file sharing
- [x] CasaOS integration
- [x] Firewall (UFW/firewalld)
- [x] SSH hardening
- [x] AI CLIs (Claude, Codex, Gemini, etc.)
- [x] GitHub dev tools cloning
- [x] Backups (restic) with cron
- [x] Watchtower auto-updates

### 🔴 Critical Gaps (Must Fix Before Release)

1. **No uninstall capability** — Users need a way to remove HomeOS
2. **No pre-flight checks** — Installer should verify disk space, RAM, internet, ports before starting
3. **No rollback on failure** — If install fails partway, system is in inconsistent state
4. **Missing `homeos` commands** — `logs`, `restart`, `backup`, `config` commands needed
5. **No upgrade path** — `homeos update` is just re-run; need differential updates
6. **Missing health checks for stacks** — `homeos doctor` doesn't check if HA/Jellyfin are actually responding

### 🟡 Important Gaps (Should Fix Before Release)

7. **No `--dry-run` mode** — Users can't preview what will be installed
8. **No `--version` flag** — Can't check installer version easily
9. **Missing disk usage warnings** — Should warn if <10GB free
10. **No backup/restore for config** — `/etc/homeos/homeos.conf` should be backed up
11. **Missing `homeos logs` command** — View container logs easily
12. **No self-test after install** — Should run `homeos doctor` automatically at end
13. **Missing progress indicator** — Long installs feel frozen
14. **No `--yes` flag** — Non-interactive but not fully unattended (accept defaults)

### 🟢 Nice to Have (Post-Release)

15. Web-based setup wizard
16. Configuration validation before install
17. Multi-language support
18. Plugin/extension system

---

## 2. PRODUCT OWNER (PO) — Backlog & Acceptance Criteria

### Must Have for v1.0.0

#### US-001: Uninstall Script

**AC:**

- `homeos uninstall` removes all HomeOS components
- Prompts for confirmation
- `--yes` flag for non-interactive
- Removes Docker stacks but optionally preserves data volumes
- Removes homeos CLI, config, cron jobs
- Optionally removes installed packages (Docker, Node, etc.)

#### US-002: Pre-Flight Checks

**AC:**

- Check minimum disk space (10GB recommended)
- Check minimum RAM (2GB recommended, 4GB for full)
- Check internet connectivity
- Check if required ports are available
- Check if running as root
- Check OS compatibility
- `--skip-checks` flag to bypass
- Exit with clear error message if checks fail

#### US-003: Rollback on Failure

**AC:**

- Track which sections completed successfully
- On failure, offer to rollback completed sections
- Create snapshot of modified files before changes
- Log all changes for manual rollback

#### US-004: Enhanced homeos CLI

**AC:**

- `homeos logs <service>` — tail container logs
- `homeos restart <service>` — restart container/stack
- `homeos backup` — trigger restic backup
- `homeos config` — edit/view config file
- `homeos uninstall` — remove HomeOS
- `homeos --version` — show version

#### US-005: Stack Health Checks

**AC:**

- `homeos doctor` checks HTTP endpoints for HA (8123), Jellyfin (8096), etc.
- Reports which stacks are healthy vs unhealthy
- Checks disk usage warnings

### Should Have for v1.0.0

#### US-006: Dry-Run Mode

**AC:**

- `--dry-run` shows what would be installed without making changes
- Lists packages, ports, users that would be created

#### US-007: Version Flag

**AC:**

- `install.sh --version` outputs version
- `homeos --version` outputs version

#### US-008: Config Backup

**AC:**

- Backup existing `/etc/homeos/homeos.conf` before overwriting
- Timestamped backups

#### US-009: Progress Indicator

**AC:**

- Show progress percentage or step X/Y during install
- Time estimates per section

---

## 3. CTO — Technical Architecture, Security, Maintainability

### 🔴 Critical Technical Debt

#### SEC-001: Secrets in Config File

**Risk:** API keys, tokens stored in plain text config file
**Fix:**

- Support environment variable references in config: `ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}`
- Document secure config file permissions (600)
- Support `.env` file loading

#### SEC-002: Sudoers NOPASSWD

**Risk:** Admin user has passwordless sudo (convenience vs security tradeoff)
**Fix:**

- Document security implications
- Offer `--secure-sudo` flag that requires password
- Add warning during interactive install

#### SEC-003: curl | bash Pattern

**Risk:** One-liner install executes remote code without verification
**Fix:**

- Add checksum verification option
- Document manual download + verify + run workflow
- Sign releases with GPG

#### SEC-004: Docker Socket Exposure

**Risk:** Watchtower mounts Docker socket; CasaOS script is unverified
**Fix:**

- Document security tradeoffs
- CasaOS install should be opt-in with warning

#### SEC-005: Default Password

**Risk:** Default admin password is username
**Fix:**

- Generate random password in unattended mode and output it
- In interactive mode, prompt for password

### 🔴 Architecture Gaps

#### ARCH-001: No Error Recovery

**Risk:** Partial install leaves system in unknown state
**Fix:**

- Implement section-level transaction log
- Store state in `/var/lib/homeos/install.state`
- Support `--resume` for interrupted installs

#### ARCH-002: Hardcoded URLs

**Risk:** External dependencies (NodeSource, Docker, CasaOS) may change
**Fix:**

- Move URLs to config/variables
- Add URL override options
- Document dependency versions

#### ARCH-003: No Update Mechanism

**Risk:** `homeos update` just re-runs installer; no differential updates
**Fix:**

- Implement version check against GitHub
- Only update changed components
- Support `--update-only <component>`

#### ARCH-004: Missing Tests

**Risk:** No automated test suite
**Fix:**

- Unit tests for config parsing
- Integration tests in Docker
- CI/CD pipeline (GitHub Actions)

### 🟡 Code Quality

#### QUAL-001: No Function Documentation

**Fix:** Add docstrings to all functions

#### QUAL-002: Magic Numbers

**Fix:** Move port numbers, timeouts, sizes to named constants

#### QUAL-003: No Error Codes

**Fix:** Define exit codes (0=success, 1=generic error, 2=missing root, etc.)

---

## 4. CEO — Market Readiness, Brand, Documentation

### 🔴 Must Have for Launch

#### MKT-001: README Completeness

**Current:** Basic README exists
**Missing:**

- Clear "What is HomeOS?" elevator pitch
- Feature comparison table (vs CasaOS, Umbrel, etc.)
- Screenshot or ASCII diagram of architecture
- Hardware requirements
- Security considerations section
- Troubleshooting guide
- FAQ

#### MKT-002: One-Liner Install

**Current:** `curl | sudo bash` works
**Missing:**

- Signed checksums for verification
- Alternative: `wget` one-liner
- Manual install instructions for paranoid users

#### MKT-003: Release Assets

**Missing:**

- GitHub release with signed checksums
- `install.sh` as standalone downloadable
- `homeos.conf.example` prominently linked

#### MKT-004: Contributing Guide

**Missing:**

- `CONTRIBUTING.md`
- Development setup instructions
- Testing requirements
- Code style guide

### 🟡 Should Have for Launch

#### MKT-005: Website/Landing Page

**Missing:** Simple GitHub Pages site

#### MKT-006: Video Demo

**Missing:** 2-minute install demo GIF/video

#### MKT-007: Community

**Missing:** Discord/Forum link, issue templates

---

## Summary: Release Blockers

### Must Fix (v1.0.0 Blockers)

1. **Uninstall script** (`homeos uninstall`)
2. **Pre-flight checks** (disk, RAM, internet, ports)
3. **Enhanced homeos CLI** (`logs`, `restart`, `backup`, `config`, `--version`)
4. **Stack health checks** in `homeos doctor`
5. **Secrets handling** (env vars, secure permissions)
6. **Default password security** (random or prompted)
7. **README completeness** (requirements, security, troubleshooting, FAQ)
8. **Rollback/resume support** (install state tracking)
9. **Signed release checksums**
10. **CONTRIBUTING.md**

### Should Fix (v1.0.0 Nice to Have)

11. Dry-run mode
12. Progress indicator
13. Config backup
14. Error codes
15. `--yes` flag

### Post-Release

16. Web wizard
17. CI/CD pipeline
18. Website
19. Video demo

---

## Test Coverage Summary

| OS           | Mode        | Docker | Stacks                | Result |
| ------------ | ----------- | ------ | --------------------- | ------ |
| Debian 12    | minimal     | ✅     | N/A                   | PASS   |
| Debian 12    | full        | ✅     | compose files written | PASS   |
| Debian 12    | idempotency | ✅     | N/A                   | PASS   |
| Ubuntu 24.04 | full        | ✅     | compose files written | PASS   |
| Fedora 40    | minimal     | ✅     | N/A                   | PASS   |
| Fedora 40    | full        | ✅     | compose files written | PASS   |

**Shellcheck:** Clean ✅

---

## Recommendation

**Ship v1.0.0 after fixing the 10 Must Fix blockers.** The core installer is solid and tested across 3 OS families. The blockers are primarily around safety (uninstall, pre-flight), security (passwords, secrets), and documentation — not core functionality.
