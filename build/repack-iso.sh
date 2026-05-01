#!/usr/bin/env bash
# Repack the upstream Debian netinst ISO with our preseed + bootstrap files.
# Runs inside the homeos-builder Docker container.
#
# Usage: repack-iso.sh <input-iso> <output-iso> [arch]
#   arch: amd64 (default) | arm64
set -euo pipefail

IN="${1:?input iso required}"
OUT="${2:?output iso required}"
ARCH="${3:-amd64}"
WORK="/tmp/homeos-iso-build"
SRC="/work"

case "$ARCH" in
  amd64) INSTALL_DIR="install.amd" ;;
  arm64) INSTALL_DIR="install.a64" ;;
  *) echo "[repack] unsupported arch: $ARCH" >&2; exit 2 ;;
esac

echo "[repack] arch:   $ARCH"
echo "[repack] input:  $IN"
echo "[repack] output: $OUT"

rm -rf "$WORK"
mkdir -p "$WORK/extract"

echo "[repack] extracting upstream ISO"
xorriso -osirrox on -indev "$IN" -extract / "$WORK/extract" >/dev/null
chmod -R u+w "$WORK/extract"

EXTRACT="$WORK/extract"

echo "[repack] embedding preseed.cfg into initrd ($INSTALL_DIR)"
mkdir -p "$WORK/initrd"
pushd "$WORK/initrd" >/dev/null
INITRD_SRC="$EXTRACT/$INSTALL_DIR/initrd.gz"
[ -f "$INITRD_SRC" ] || { echo "[repack] missing $INITRD_SRC"; exit 1; }
gunzip -c "$INITRD_SRC" | cpio -id --quiet
cp "$SRC/preseed/preseed.cfg" preseed.cfg
find . | cpio -o -H newc --quiet | gzip -9 > "$INITRD_SRC"
popd >/dev/null

echo "[repack] copying boot configs"
install -m 644 "$SRC/preseed/grub.cfg" "$EXTRACT/boot/grub/grub.cfg"
if [ "$ARCH" = "amd64" ] && [ -d "$EXTRACT/isolinux" ]; then
  install -m 644 "$SRC/preseed/isolinux.cfg" "$EXTRACT/isolinux/isolinux.cfg"
fi

echo "[repack] copying homeos bootstrap payload"
mkdir -p "$EXTRACT/homeos"
rsync -a --delete \
  --exclude 'dist/' --exclude 'build/cache/' --exclude '.git/' \
  "$SRC/bootstrap/" "$EXTRACT/homeos/bootstrap/"
install -d -m 755 "$EXTRACT/homeos/secrets"
if [ -s "$SRC/secrets/authorized_keys" ]; then
  install -m 600 "$SRC/secrets/authorized_keys" "$EXTRACT/homeos/secrets/authorized_keys"
  echo "[repack] baked authorized_keys into ISO"
else
  : > "$EXTRACT/homeos/secrets/authorized_keys"
  chmod 600 "$EXTRACT/homeos/secrets/authorized_keys"
  echo "[repack] PUBLIC build — no authorized_keys baked; admin/homeos password fallback"
fi

echo "[repack] regenerating md5sum.txt"
pushd "$EXTRACT" >/dev/null
find . -type f ! -name md5sum.txt -print0 \
  | xargs -0 md5sum > md5sum.txt
popd >/dev/null

echo "[repack] building ISO ($ARCH)"
if [ "$ARCH" = "amd64" ]; then
  xorriso -as mkisofs \
    -r -V "HOMEOS_TRIXIE" \
    -o "$OUT" \
    -J -joliet-long -cache-inodes \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 -boot-info-table -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$EXTRACT"
else
  # arm64 — EFI-only, no isolinux/MBR.
  xorriso -as mkisofs \
    -r -V "HOMEOS_TRIXIE" \
    -o "$OUT" \
    -J -joliet-long -cache-inodes \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$EXTRACT"
fi

echo "[repack] DONE: $OUT"
