# HomeOS Universal Installer — Test Report

**Date:** 2026-05-04
**Installer Version:** 1.0.0
**Commit:** `post-e8737fd`

---

## Test Matrix

| OS                   | Mode        | Components                             | Result  | Time    |
| -------------------- | ----------- | -------------------------------------- | ------- | ------- |
| Debian 12 (bookworm) | minimal     | base, docker, node                     | ✅ PASS | ~2m     |
| Debian 12 (bookworm) | full        | base, docker, node, caddy, cockpit     | ✅ PASS | ~3m 45s |
| Debian 12 (bookworm) | idempotency | re-run full mode on installed system   | ✅ PASS | ~2m 30s |
| Debian 12 (bookworm) | regression  | post-bugfix validation                 | ✅ PASS | ~3m 30s |
| Debian 12 (bookworm) | post-review | base, docker, node, CLI, idempotency   | ✅ PASS | ~4m     |
| Debian 12 (bookworm) | targeted    | config injection, uninstall, Grafana   | ✅ PASS | <1m     |
| Debian 12 (bookworm) | v1.1 smoke  | config-path, purge parse, Grafana bind | ✅ PASS | <1m     |
| Fedora 40            | minimal     | base, docker, node                     | ✅ PASS | ~2m 15s |

---

## Debian 12 Minimal Mode Results

```
✓ Base system installed (curl, git, sudo, vim, tmux, htop, jq, ufw, etc.)
✓ Docker CE 29.4.2 installed
✓ Node.js v24.15.0 + npm 11.12.1 installed
✓ pnpm activated via corepack
✓ Bun installed to ~/.bun/bin/bun
✓ Admin user 'admin' created (uid=1000, gid=1000, groups=sudo,docker)
✓ homeos CLI installed at /usr/local/bin/homeos
✓ Data directory /opt/homeos created
✓ Install log written to /var/log/homeos-install.log
```

## Debian 12 Full Mode Results

```
✓ All minimal mode components
✓ Caddy v2.11.2 installed
✓ Caddyfile created at /etc/caddy/Caddyfile
✓ Cockpit installed
✓ 45Drives modules installed (file-sharing, navigator, identities)
✓ Watchtower compose file written (container start deferred — no daemon in test env)
✓ Graceful handling of missing docker daemon
✓ Graceful handling of missing systemd
```

## Idempotency Test Results

Running the installer a second time on the same system:

```
✓ No duplicate package installations (apt reports "0 upgraded, 0 newly installed")
✓ No duplicate user creation (idempotent check)
✓ No duplicate sudoers file creation
✓ No duplicate API key exports in ~/.bashrc (0 duplicates)
✓ Docker correctly reports "already installed"
✓ Node.js correctly reports "already installed"
✓ All sections complete successfully
✓ EXIT_CODE=0
```

**Verified on second run:**

- No duplicate package installations
- No duplicate API key exports (key_count=0)
- Docker correctly reports "already installed"
- All sections complete successfully
- `homeos --version`, `homeos status`, `homeos doctor` all functional

## Fedora 40 Minimal Mode Results

```
✓ Base system installed (dnf packages)
✓ Docker CE 28.1.1 installed
✓ Node.js v20.19.1 + npm 10.8.2 installed
  Note: Fedora default repos provide Node v20. For v24, use Nodesource or build from source.
✓ Admin user 'admin' created with wheel group (uid=1000, gid=1000, groups=wheel,docker)
✓ homeos CLI installed at /usr/local/bin/homeos
✓ Data directory /opt/homeos created
```

**Critical fix applied:** Fedora uses `wheel` group instead of `sudo` for admin privileges.

---

## Fixes Applied During Testing

### 1. NodeSource GPG Key Handling

**Problem:** Manual `gpg --dearmor` of NodeSource key failed with `NO_PUBKEY` error on clean Debian installs.
**Fix:** Replaced manual keyring setup with official NodeSource `setup_24.x` script.

### 2. systemd Unavailable in Containers

**Problem:** `systemctl enable --now` failed in Docker containers and WSL without systemd.
**Fix:** `pkg_service_enable()` now checks for `systemctl` availability and skips gracefully.

### 3. Docker Daemon Not Running

**Problem:** `docker compose up -d` crashed the script when Docker daemon wasn't running (containers, test envs).
**Fix:** All stack deployments now use `|| warn` fallback with descriptive message.

### 4. Forced Password Change in Unattended Mode

**Problem:** `passwd -e` broke `su -` authentication during unattended installs.
**Fix:** Skip `passwd -e` when `HOMEOS_UNATTENDED=yes`.

### 5. Bun Install Failures

**Problem:** Bun install via `su -` could fail and abort the script.
**Fix:** Made non-fatal with `|| warn "Bun install failed (non-fatal)"`.

### 6. API Key Duplication

**Problem:** API keys were appended to `.bashrc` on every run, creating duplicates.
**Fix:** Check if key already exists before appending.

### 7. Fedora `sudo` Group Missing

**Problem:** `useradd -G sudo` failed on Fedora because the group is named `wheel`.
**Fix:** Use `wheel` group on RHEL family, `sudo` on Debian family.

### 8. GPG TTY Required

**Problem:** `gpg --dearmor` tried to open `/dev/tty` in non-interactive environments.
**Fix:** Added `--batch --yes` flags to GPG dearmor operations.

### 9. Config Guard Gates

**Problem:** `install_homeos_cli()` and `install_watchtower()` always ran regardless of config.
**Fix:** Added `INSTALL_BASE` and `INSTALL_DOCKER` guard checks respectively.

### 10. Shellcheck Compliance

**Fix:** Removed unused variables (`HI_LIB_DIR`, `HOMEASSISTANT_API_TOKEN`, `ENABLE_AUDIT`), fixed `=~` regex quoting.

### 11. ufw Syntax Error

**Problem:** `ufw --force allow 22/tcp` is invalid syntax — `--force` only works with `enable/disable/reset`, not `allow`.
**Fix:** Removed `--force` from `ufw allow` commands; added `|| warn` for graceful failure in containers.

### 12. Container Firewall Failures

**Problem:** `ufw --force enable` crashes in unprivileged containers because iptables/netfilter isn't available.
**Fix:** Made all ufw commands container-safe with `|| warn` fallbacks.

### 13. RAM Check in Containers

**Problem:** `free -m` returns 0MB in Docker containers because cgroup memory limits aren't visible.
**Fix:** Added `/proc/meminfo` fallback and graceful skip for container environments.

### 14. External Review Fixes

**Problems found by GLM-5.1/MiniMax M2.7 review:** unsafe `eval` config expansion, `--yes uninstall` argument order bug, non-interactive uninstall prompts, incomplete HomeOS-owned cleanup, Grafana default password, unattended-upgrades sed mismatch, and secret-generation fallback SIGPIPE under `pipefail`.
**Fix:** Replaced eval expansion with strict `$VAR`/`${VAR}` expansion, unified command parsing, made uninstall automation-safe, cleaned HomeOS-owned artifacts, generated a random Grafana password, fixed sed to `[[:space:]]*`, and hardened secret generation.

### 15. homeos CLI Uptime Fallback

**Problem:** Minimal Debian containers may not include `uptime`; `homeos status` printed `command not found` under `set -euo pipefail`.
**Fix:** Added safe OS/uptime detection with `command -v uptime` and `unavailable` fallback.

### 16. v1.1 Follow-up Improvements

**Fixes:** Custom `--config` paths are recorded under `/var/lib/homeos/config-path` so `homeos update` can re-use them; `uninstall --purge --yes` can remove HomeOS-installed packages/repos; Grafana now binds to `127.0.0.1:3000` by default and can be changed with `GRAFANA_BIND_ADDRESS`.

---

## Known Limitations

1. **Fedora Node.js version:** Fedora default repos provide Node v20, not v24. The installer accepts this. For v24 on Fedora, manual NodeSource setup or building from source is required.

2. **Docker containers:** Full stack deployment (Home Assistant, Jellyfin, etc.) requires a running Docker daemon. In test containers without a daemon, compose files are written but containers don't start — this is expected behavior.

3. **Cockpit on Fedora:** 45Drives modules are Debian-only; Fedora gets base Cockpit only.

4. **CasaOS:** Installation relies on the official CasaOS install script which may change.

5. **AI CLIs:** Some CLIs (Cursor, Kimi, Opencode) use vendor install scripts that may fail silently; these are non-fatal.

---

## Security Notes

- Admin user gets password same as username (`admin:admin`) — forced change on first login in interactive mode
- SSH hardening disables root login and enables key auth when keys are present
- Sudoers file is created with restrictive permissions (440)
- API keys are stored in admin's `.bashrc` — consider using a dedicated secrets file for production
- Firewall defaults deny incoming, allow outgoing
- Backup configuration requires manual `BACKUP_TARGET` and password file setup

---

## Commands to Reproduce Tests

```bash
# Debian 12 minimal
docker run --rm -it --privileged -v $(pwd)/universal-installer:/installer:ro debian:bookworm bash
# Inside container:
apt-get update -qq && apt-get install -y -qq curl sudo ca-certificates
bash /installer/install.sh --unattended --mode minimal

# Fedora 40 minimal
docker run --rm -it --privileged -v $(pwd)/universal-installer:/installer:ro fedora:40 bash
# Inside container:
dnf install -y -q curl sudo ca-certificates
bash /installer/install.sh --unattended --mode minimal
```

---

## Sign-off

| Check                 | Status |
| --------------------- | ------ |
| Shellcheck clean      | ✅     |
| Debian 12 minimal     | ✅     |
| Debian 12 full        | ✅     |
| Debian 12 idempotent  | ✅     |
| Debian post-review    | ✅     |
| v1.1 smoke checks     | ✅     |
| Fedora 40 minimal     | ✅     |
| homeos CLI functional | ✅     |
| Install log complete  | ✅     |
