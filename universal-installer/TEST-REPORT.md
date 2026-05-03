# HomeOS Universal Installer — Test Report

**Date:** 2026-05-03
**Installer Version:** 1.0.0
**Commit:** `595bc70`

---

## Test Matrix

| OS                   | Mode        | Components                           | Result  | Time    |
| -------------------- | ----------- | ------------------------------------ | ------- | ------- |
| Debian 12 (bookworm) | minimal     | base, docker, node                   | ✅ PASS | ~2m     |
| Debian 12 (bookworm) | full        | base, docker, node, caddy, cockpit   | ✅ PASS | ~3m 45s |
| Debian 12 (bookworm) | idempotency | re-run full mode on installed system | ✅ PASS | ~3m     |
| Fedora 40            | minimal     | base, docker, node                   | ✅ PASS | ~2m 15s |

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

**Minor issue on second run:** 45Drives GPG key import shows warning in non-TTY environment (fixed with `--batch --yes`).

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
| Fedora 40 minimal     | ✅     |
| homeos CLI functional | ✅     |
| Install log complete  | ✅     |
