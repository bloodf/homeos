#!/usr/bin/env bash
# Download + verify Debian 13.4 netinst ISO.
# Usage: download-base-iso.sh <output-path> [amd64|arm64]
set -euo pipefail

OUT="${1:?output path required}"
ARCH="${2:-amd64}"
VERSION="13.4.0"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PINNED_SUMS="${ROOT}/build/debian-base-isos.sha256"
DEBIAN_CD_KEYRING="${ROOT}/build/debian-cd-signing-key.gpg"
case "$ARCH" in
amd64 | arm64) ;;
*)
	echo "[base-iso] unsupported arch: $ARCH" >&2
	exit 2
	;;
esac
FILE="debian-${VERSION}-${ARCH}-netinst.iso"
MIRROR="https://cdimage.debian.org/cdimage/release/${VERSION}/${ARCH}/iso-cd"

mkdir -p "$(dirname "$OUT")"

EXPECTED="$(awk -v f="$FILE" '$2 == f { print $1 }' "$PINNED_SUMS")"
if [ -z "$EXPECTED" ]; then
	echo "[base-iso] no pinned checksum for $FILE in $PINNED_SUMS" >&2
	exit 1
fi

if [ -s "$OUT" ]; then
	echo "[base-iso] already cached: $OUT"
else
	echo "[base-iso] downloading $FILE"
	curl -fSL --retry 3 -o "$OUT" "${MIRROR}/${FILE}"
fi

ACTUAL="$(sha256sum "$OUT" | awk '{print $1}')"
if [ "$EXPECTED" != "$ACTUAL" ]; then
	echo "[base-iso] CHECKSUM MISMATCH against pinned manifest"
	echo "  file:     $FILE"
	echo "  expected: $EXPECTED"
	echo "  actual:   $ACTUAL"
	rm -f "$OUT"
	exit 1
fi

echo "[base-iso] fetching signed upstream SHA256SUMS for provenance cross-check"
SUMS_URL="${MIRROR}/SHA256SUMS"
SIG_URL="${SUMS_URL}.sign"
SUMS_FILE="$(dirname "$OUT")/SHA256SUMS"
SIG_FILE="$(dirname "$OUT")/SHA256SUMS.sign"
[ -s "$DEBIAN_CD_KEYRING" ] || { echo "[base-iso] missing Debian CD keyring: $DEBIAN_CD_KEYRING" >&2; exit 1; }
command -v gpgv >/dev/null 2>&1 || { echo "[base-iso] gpgv required to verify SHA256SUMS.sign" >&2; exit 1; }
curl -fSL --retry 3 --connect-timeout 15 --max-time 120 -o "$SUMS_FILE" "$SUMS_URL"
curl -fSL --retry 3 --connect-timeout 15 --max-time 120 -o "$SIG_FILE" "$SIG_URL"
gpgv --keyring "$DEBIAN_CD_KEYRING" "$SIG_FILE" "$SUMS_FILE"

UPSTREAM="$(awk -v f="$FILE" '$2 == f { print $1 }' "$SUMS_FILE")"
if [ -z "$UPSTREAM" ]; then
	echo "[base-iso] upstream SHA256SUMS does not list $FILE" >&2
	exit 1
fi
if [ "$EXPECTED" != "$UPSTREAM" ]; then
	echo "[base-iso] pinned checksum no longer matches upstream SHA256SUMS" >&2
	echo "  pinned:   $EXPECTED" >&2
	echo "  upstream: $UPSTREAM" >&2
	exit 1
fi

echo "[base-iso] OK: $OUT"
