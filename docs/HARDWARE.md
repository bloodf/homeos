# Hardware Compatibility

## Tested

| Class | Example | Status |
|---|---|---|
| Intel NUC (Gen 9+) | NUC11, NUC12 | ✅ full support including Jellyfin QSV |
| Mini PC (N100/N305) | Beelink S12, GMKtec NucBox | ✅ full support, QSV works |
| Custom build (i3/i5 12th-gen+ + iGPU) | DIY | ✅ full support |
| Old laptop, x86_64 | ThinkPad T480, X1 | ✅ works (no QSV on Gen 8 and older) |
| Raspberry Pi 5 (arm64) | RPi5 8 GB | ⚠️ boots, no GPU transcoding |
| Apple Silicon Mac | (via UTM/QEMU) | ❌ ISO doesn't apply — use the arm64 build for native arm64 boards instead |

## Minimum

- **CPU**: x86_64 with EFI **or** legacy BIOS, or arm64 (UEFI required).
- **RAM**: 4 GB. 8 GB recommended (Jellyfin transcoding + HA + Docker).
- **Disk 1**: 60 GB SSD/NVMe minimum. 120 GB recommended.
- **Disk 2**: optional. 20 GB minimum. Used for swap + LVM cache.
- **Network**: wired, DHCP-capable. Wi-Fi works in the kernel but is not
  auto-configured.

## GPU

### Intel iGPU (Gen 9+) — fully supported

Skylake (Gen 9) and newer. Bootstrap installs:
- `intel-media-va-driver-non-free` (iHD)
- `i965-va-driver` (legacy)
- `vainfo`, `intel-gpu-tools`

`vainfo | grep iHD` should show the driver after first boot.

Jellyfin compose passes `/dev/dri` and adds `group_add: [render]`. Hardware
transcoding is enabled in Jellyfin's Playback settings (set "Hardware
acceleration" to "Intel QuickSync (QSV)").

### AMD iGPU / dGPU — works, manual tuning

VAAPI works via `mesa-va-drivers` (already pulled by `intel-media-va-driver-non-free`'s
deps). Jellyfin acceleration: choose "VAAPI" instead of "QSV".

### Nvidia — out of scope

The proprietary stack (driver + container toolkit) is intentionally not
included. If you want it: install manually after first boot and edit the
Jellyfin compose to add the nvidia runtime.

## Disks

### Recommended layout

```
Disk 1 (sda):
  /dev/sda1   ext4   1 GB    /boot
  /dev/sda2   LVM    rest    vg0 → vg0/root (ext4)

Disk 2 (sdb):
  /dev/sdb    LVM    full    vg1 → vg1/swap (16 GB)
                              vg1/cache (rest, attached to vg0/root)
```

The LVM cache attach happens in the `base` Ansible role only if `vg1/cache`
exists. Single-disk boxes skip cache and run swap as a swap **file** on
`/`.

### Single-disk fallback

The preseed `late_command` second-disk step is wrapped with `|| true`. If
`/dev/sdb` doesn't exist, the install proceeds. The bootstrap creates
`/swapfile` (8 GB) instead of an LVM swap LV.

### Disk roles for NAS

USB drives are **never** repartitioned by HomeOS. They are added at runtime
via `homeos config nas add /dev/sdcN`. See [NAS.md](NAS.md).

## Networking

### Required at install

- DHCP server on the wired network.
- IPv4. (IPv6 works but Stage A doesn't depend on it.)

### Required at first boot

- Outbound HTTPS to:
  - `deb.debian.org` (apt)
  - `download.docker.com`
  - `pkgs.tailscale.com`
  - `dl.cloudsmith.io`
  - `deb.nodesource.com`
  - `registry.npmjs.org`
  - `github.com` + `objects.githubusercontent.com`
  - `get.casaos.io`
  - `homebrew-bottles` (S3) for brew formulas
- Outbound to Docker Hub for image pulls (HA, Jellyfin, Vaultwarden,
  Watchtower).

### Wi-Fi

Not auto-configured. To use Wi-Fi:

```bash
sudo nmtui            # interactive
sudo nmcli device wifi connect <SSID> password <PSK>
```

Then re-run bootstrap if Stage B failed due to no network:

```bash
sudo homeos config rerun-bootstrap
```

## Form factor recommendations

| Use case | Recommendation | Why |
|---|---|---|
| Quiet 24/7 always-on | Mini PC with N100/N305 | 6–10 W idle, fanless, plenty of perf for everything HomeOS does |
| Heavy transcoding (4K HDR) | Intel 12th-gen+ NUC or DIY | iGPU with AV1 encode, more RAM headroom |
| Media-heavy NAS | DIY ATX with HBA + 4–8 USB ports | More disk slots = more storage. RAID via mdadm or zfs is your job. |
| Just-trying-it-out | Old laptop you have lying around | Free hardware. Works fine for HA + low-bitrate Jellyfin. |

## Power

- TDP target: ≤ 25 W idle for "always-on" use.
- UPS recommended. Cockpit UI shows UPS status if you install `nut`
  manually.
- Wake-on-LAN works on most boards — useful if you want to suspend overnight
  and wake on demand.

## ARM64 specifics

The arm64 ISO is EFI-only (no BIOS, no isolinux). Tested on:
- QEMU virt machine (`-machine virt -accel tcg`)
- Generic UEFI arm64 boards

It will **not** boot on a Raspberry Pi out of the box — RPis have their own
boot path (config.txt, no UEFI). A bespoke RPi image is future work.

For native arm64 servers (Ampere Altra, AWS Graviton via bare metal, etc.):

```bash
make ARCH=arm64 iso
```

Pass `ARCH=arm64` to `make qemu-test` after adding a virt-machine target.
