#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/digests" "$TMP/admin"

touch "$TMP/bootstrapped"
export HOMEOS_STACK_DIGEST_DIR="$TMP/digests"
export HOMEOS_BOOTSTRAPPED_MARKER="$TMP/bootstrapped"
export HOMEOS_BOOTSTRAP_FAILED_MARKER="$TMP/bootstrap-failed"
export HOMEOS_ADMIN_HOME="$TMP/admin"
export HOMEOS_BACKUP_ENV="$TMP/backup.env"

HOMEOS="$ROOT/bootstrap/roles/homeos-cli/files/homeos"

# Path traversal must be rejected before /opt/stacks lookup.
if "$HOMEOS" config stack digests ../bad >/tmp/homeos-bad-stack.out 2>&1; then
	echo "invalid stack name unexpectedly succeeded" >&2
	exit 1
fi
grep -q 'invalid stack name' /tmp/homeos-bad-stack.out

echo '{"schema":"homeos.stack-digests.v1","stack":"demo","services":[]}' >"$TMP/digests/demo-20260101T000000Z.json"
# The digests listing is read-only and does not require Docker.
"$HOMEOS" config stack digests demo 2>/dev/null | grep -q 'demo-20260101T000000Z.json'

echo "homeos stack snapshot tests OK"
