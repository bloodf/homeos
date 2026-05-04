# HomeOS Installer External Review Fixes

**Date:** 2026-05-04
**Reviewers:** GLM-5.1, MiniMax M2.7, parent agent verification

## Validated Findings Fixed

1. **Unsafe config expansion**
   - Removed `eval echo` from config loading.
   - `${VAR}` and `$VAR` now expand only simple environment variable names.
   - Command substitution like `$(...)` is treated as literal text.

2. **Uninstall command parsing**
   - `install.sh --yes uninstall` and `install.sh uninstall --yes` now both route to uninstall.
   - Previously only `install.sh uninstall` worked because uninstall had to be the first argument.

3. **Non-interactive uninstall**
   - `--yes` auto-confirms component removal and Docker volume removal.
   - `--unattended uninstall` auto-confirms component removal but preserves Docker volumes by default.

4. **Uninstall cleanup completeness**
   - Removes HomeOS SSH hardening drop-in.
   - Removes HomeOS sudoers drop-in.
   - Removes 45Drives apt source/key created by HomeOS.
   - Removes HomeOS Caddyfile only when it matches HomeOS-generated content.
   - Removes Docker daemon config only when it matches the HomeOS network-pool config.

5. **Unattended-upgrades security config**
   - Replaced non-matching sed `\s` pattern with POSIX `[[:space:]]*`.

6. **Grafana default credential**
   - No longer uses `admin`/admin username as Grafana password.
   - Generates a random Grafana password when monitoring is enabled and no `GRAFANA_ADMIN_PASSWORD` is configured.
   - Stores generated password at `/var/lib/homeos/grafana-password.txt` with `0600` permissions.

7. **Secret generation under `pipefail`**
   - Fixed fallback random generation so `tr | head` SIGPIPE does not return exit 141 under `set -euo pipefail`.

8. **`homeos uninstall` CLI command**
   - Replaced the stale `/installer/install.sh` path fallback with the same latest-installer download path used by `homeos update`.

9. **`homeos update` config preservation**
   - When `/etc/homeos/homeos.conf` exists, `homeos update` now passes it back into the installer.

## Findings Reviewed and Rejected

1. **`pkg_service_enable` set-e blocker**
   - Rejected: commands inside `if` conditions and OR lists are exempt from `set -e` abort behavior.
   - Verified with `bash -c 'set -e; if false || false; then :; else :; fi; echo ok'`.
   - Existing full container regression tests also passed through `pkg_service_enable` repeatedly.

2. **`apt-listchanges` missing on Debian 12**
   - Rejected: Debian 12 installs it successfully in existing test logs.

3. **`homeos update` regenerates admin password**
   - Mostly rejected: admin password generation only happens when creating a missing admin user. Updates on installed systems do not recreate the user.
   - Remaining limitation: custom non-default config path is not preserved by `homeos update`; track for v1.1.

## Verification Commands Run

```bash
shellcheck --severity=warning universal-installer/install.sh
bash -n universal-installer/install.sh
```

Targeted Docker checks:

- Config injection does not execute command substitution (`CONFIG_INJECTION_OK`).
- `--yes uninstall` routes to uninstall and does not start installation (`UNINSTALL_PARSE_OK`).
- Monitoring-only install generates a non-admin Grafana password and writes it to compose (`GRAFANA_PASSWORD_OK`).
- Sed pattern now converts commented unattended-upgrades security line correctly.

## Current Recommendation

Release can proceed after final commit/push. Remaining non-blocking v1.1 items:

- Preserve non-standard custom `--config` paths in `homeos update`.
- Add optional full uninstall mode for package/repository removal.
- Consider binding Grafana to localhost/Tailscale only by default.
