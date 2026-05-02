#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/admin" "$TMP/root" "$TMP/etc" "$TMP/state" "$TMP/digests"

touch "$TMP/state/bootstrapped"
cat >"$TMP/etc/backup.env" <<EOF
RESTIC_REPOSITORY=$TMP/restic
RESTIC_PASSWORD_FILE=$TMP/restic.pass
BACKUP_PATHS="$TMP/admin"
EOF

cat >"$TMP/bin/systemctl" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  is-active) echo inactive; exit 3 ;;
  show) echo inactive; exit 0 ;;
  --failed) exit 0 ;;
  *) exit 0 ;;
esac
SH
cat >"$TMP/bin/journalctl" <<'SH'
#!/usr/bin/env bash
echo journalctl-stub "$@"
SH
cat >"$TMP/bin/docker" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  info) echo /tmp/docker; exit 0 ;;
  ps) exit 0 ;;
  *) echo docker-stub "$@"; exit 0 ;;
esac
SH
cat >"$TMP/bin/tailscale" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = status ] && exit 0
exit 0
SH
cat >"$TMP/bin/caddy" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$TMP/bin/apt-get" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = -s ] && { echo apt-simulated; exit 0; }
exit 0
SH
chmod +x "$TMP/bin"/*

export PATH="$TMP/bin:$PATH"
export HOMEOS_ADMIN_HOME="$TMP/admin"
export HOMEOS_ROOT="$ROOT"
export HOMEOS_BACKUP_ENV="$TMP/etc/backup.env"
export HOMEOS_BOOTSTRAPPED_MARKER="$TMP/state/bootstrapped"
export HOMEOS_BOOTSTRAP_FAILED_MARKER="$TMP/state/bootstrap-failed"
export HOMEOS_STACK_DIGEST_DIR="$TMP/digests"
export HOMEOS_AUDIT_LOG="$TMP/audit.jsonl"

HOMEOS="$ROOT/bootstrap/roles/homeos-cli/files/homeos"

out="$($HOMEOS init --dry-run --skip-secure --skip-tailscale --skip-secrets --skip-nas --skip-backup)"
grep -q 'HomeOS init plan' <<<"$out"
out="$($HOMEOS upgrade --check --skip-apt --skip-docker --skip-brew)"
grep -q 'upgrade check' <<<"$out"
out="$($HOMEOS log --lines 1 summary)"
grep -q 'journalctl-stub' <<<"$out"
if "$HOMEOS" log nope >/tmp/homeos-invalid-log.out 2>&1; then
	echo "invalid log target unexpectedly succeeded" >&2
	exit 1
fi
out="$($HOMEOS diag)"
grep -q 'suggestions' <<<"$out"
out="$($HOMEOS --help)"
grep -q 'homeos init' <<<"$out"

echo "homeos CLI UX tests OK"
