#!/usr/bin/env bash
# Download + verify Debian 13.4 netinst ISO.
# Usage: download-base-iso.sh <output-path>
set -euo pipefail

OUT="${1:?output path required}"
ARCH="${2:-amd64}"
VERSION="13.4.0"
case "$ARCH" in
  amd64|arm64) ;;
  *) echo "[base-iso] unsupported arch: $ARCH" >&2; exit 2 ;;
esac
FILE="debian-${VERSION}-${ARCH}-netinst.iso"
MIRROR="https://cdimage.debian.org/cdimage/release/${VERSION}/${ARCH}/iso-cd"

mkdir -p "$(dirname "$OUT")"

if [ -s "$OUT" ]; then
  echo "[base-iso] already cached: $OUT"
else
  echo "[base-iso] downloading $FILE"
  curl -fSL --retry 3 -o "$OUT" "${MIRROR}/${FILE}"
fi

echo "[base-iso] fetching SHA256SUMS"
SUMS_URL="${MIRROR}/SHA256SUMS"
SUMS_FILE="$(dirname "$OUT")/SHA256SUMS"
curl -fSL --retry 3 -o "$SUMS_FILE" "$SUMS_URL"

EXPECTED="$(awk -v f="$FILE" '$2 == f { print $1 }' "$SUMS_FILE")"
if [ -z "$EXPECTED" ]; then
  echo "[base-iso] WARN: $FILE not in SHA256SUMS yet (point release may lag); skipping verify"
  exit 0
fi

ACTUAL="$(sha256sum "$OUT" | awk '{print $1}')"
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "[base-iso] CHECKSUM MISMATCH"
  echo "  expected: $EXPECTED"
  echo "  actual:   $ACTUAL"
  rm -f "$OUT"
  exit 1
fi

echo "[base-iso] OK: $OUT"
