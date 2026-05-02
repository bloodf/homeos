# Multi-model review and fix report

Date: 2026-05-02

## Review runs

Models used through subagents:

- `zai/glm-5.1` for latest-HEAD implementation review.
- `kimi-coding/k2p6` for security and supply-chain review.
- `minimax/MiniMax-M2.7` for latest-HEAD implementation and process review.

Notes:

- The first GLM/M2.7 prompt over-weighted release notes, so a second latest-HEAD-only review was launched.
- No subagent was allowed to edit, commit, tag, push, run QEMU, boot a VM, or build a local ISO.
- Some requested model aliases were not valid exactly as typed; reruns used available model IDs from `pi --list-models`.

## Actions taken

### CI and supply chain

- Pinned GitHub Actions by immutable commit SHA in `.github/workflows/build-iso.yml`.
- Reduced default workflow permission from `contents: write` to `contents: read`.
- Scoped `contents: write` to the release attachment job only.
- Hardened `build/refresh-pins.sh` with curl retry and timeout flags.
- Replaced fragile `awk` SHA extraction with JSON parsing.

### Portal and operational docs

- Updated `docs/PORTAL.md` to state ttyd terminals are loopback-bound behind Caddy and do not use host networking.
- Added v0.7-v0.9 entries to the `docs/AI-GATE.md` roadmap.
- Updated `FRESH-ORCHESTRATOR-HANDOFF.md` with a historical banner and current v0.9/v1.0 state.
- Updated `PROJECT-INFO.md` header to reflect the post-v0.9 state.
- Added v0.4 release date for consistency.
- Normalized the Raspberry Pi warning glyph in `docs/HARDWARE.md`.

### Runtime hardening

- Changed the Cosmos shim Unix socket mode from `0660` to `0600`.
- Replaced audit logrotate `copytruncate` with `create 0644 root root`.
- Removed repeated `chmod 0644` from every audit log write.
- Made `hash12()` fail explicitly if neither `sha256sum` nor `shasum` exists.
- Escaped NAS add/remove values by passing them as Python arguments instead of interpolating into inline Python.
- Sanitized NAS labels before using them in systemd unit names and share paths.
- Made NFS export and exfat/ntfs mount ownership use the actual admin UID/GID instead of hardcoded `1000`.
- Updated Vaultwarden `DOMAIN` to the configured tailnet hostname.
- Tightened Homepage allowed hosts to the portal hostname plus local loopback names.
- Reworked `offsite-backup.sh` environment writes to update existing keys, reject embedded newlines, and validate remote path/name shape.

### Documentation of accepted residual risk

- Added TCP 139 to the documented LAN firewall allowlist.
- Documented ISO internal `md5sum.txt` as a Debian installer compatibility artifact rather than a security boundary.
- Left Debian `SHA256SUMS` GPG verification as a future hardening candidate because the current implementation already verifies pinned local SHA256 plus upstream HTTPS checksums.
- Left CasaOS installer SHA pinning as a future hardening candidate because no stable installer checksum source was confirmed during this pass.

## Validation run after fixes

Passed locally:

- Workflow YAML parse spot-check.
- `make check-static`.
- `GITHUB_TOKEN=$(gh auth token) bash build/refresh-pins.sh --check`.
- `bash -n bootstrap/installers/offsite-backup.sh bootstrap/roles/homeos-cli/files/homeos build/refresh-pins.sh`.
- `python3 -m py_compile bootstrap/roles/cosmos/files/homeos-cosmos-docker-shim`.
- Targeted audit/Cosmos harness covering `audit show`, `audit replay`, `audit cosmos-events`, and `0o600` shim socket source check.
- `git diff --check`.

Skipped locally:

- `ansible-playbook --syntax-check bootstrap/install.yml` because `ansible-playbook` is not installed.
- QEMU, VM boot, and local ISO builds, per the v0.5-v0.9 policy.

## Remaining low-priority candidates

- Add GPG verification for Debian `SHA256SUMS` once the project decides how to vendor or fetch Debian CD signing keys.
- Pin and verify the CasaOS installer script if upstream publishes a stable checksum or signed installer path.
- Consider removing ttyd secret mounts if HomeOS moves from trusted-admin portal usage to broader shared portal access.
- Consider splitting `homeos config cosmos on` into smaller shell steps with explicit preflight checks.
