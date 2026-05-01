#!/usr/bin/env bash
# Repack the upstream Debian netinst ISO with our preseed + bootstrap files.
# Runs inside the homeos-builder Docker container.
#
# Usage: repack-iso.sh <input-iso> <output-iso>
set -euo pipefail

IN="${1:?input iso required}"
OUT="${2:?output iso required}"
WORK="/tmp/homeos-iso-build"
SRC="/work"

echo "[repack] input:  $IN"
echo "[repack] output: $OUT"

rm -rf "$WORK"
mkdir -p "$WORK/extract"

echo "[repack] extracting upstream ISO"
xorriso -osirrox on -indev "$IN" -extract / "$WORK/extract" >/dev/null
chmod -R u+w "$WORK/extract"

EXTRACT="$WORK/extract"

echo "[repack] embedding preseed.cfg into initrd"
mkdir -p "$WORK/initrd"
pushd "$WORK/initrd" >/dev/null
gunzip -c "$EXTRACT/install.amd/initrd.gz" | cpio -id --quiet
cp "$SRC/preseed/preseed.cfg" preseed.cfg
find . | cpio -o -H newc --quiet | gzip -9 > "$EXTRACT/install.amd/initrd.gz"
popd >/dev/null

echo "[repack] copying boot configs"
install -m 644 "$SRC/preseed/grub.cfg"     "$EXTRACT/boot/grub/grub.cfg"
install -m 644 "$SRC/preseed/isolinux.cfg" "$EXTRACT/isolinux/isolinux.cfg"

echo "[repack] copying homeos bootstrap payload"
mkdir -p "$EXTRACT/homeos"
rsync -a --delete \
  --exclude 'dist/' --exclude 'build/cache/' --exclude '.git/' \
  "$SRC/bootstrap/" "$EXTRACT/homeos/bootstrap/"
install -d -m 755 "$EXTRACT/homeos/secrets"
install -m 600 "$SRC/secrets/authorized_keys" "$EXTRACT/homeos/secrets/authorized_keys"

echo "[repack] regenerating md5sum.txt"
pushd "$EXTRACT" >/dev/null
find . -follow -type f ! -name md5sum.txt -print0 \
  | xargs -0 md5sum > md5sum.txt
popd >/dev/null

echo "[repack] building hybrid ISO"
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

echo "[repack] DONE: $OUT"
