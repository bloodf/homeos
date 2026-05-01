# FAQ

## Why a custom ISO instead of "install Debian, then run a script"?

Because the partition layout matters and has to happen during install. A
post-install script would have to repartition a running system, which is
fragile and may require a reboot. The custom ISO answers
`debian-installer`'s questions directly, so the box is correctly
partitioned on first boot.

It also means **flash one USB and walk away**. No keyboard interaction at
any point.

## Why Debian and not Ubuntu/Fedora/Arch?

- Debian's preseed system is the most stable unattended-installer in the
  Linux world.
- 13.4 (Trixie) ships kernel 6.12, modern enough for Intel Gen 12+ iGPUs.
- Conservative release schedule = headless boxes don't break overnight.
- Apt + signed repos for Docker/Tailscale/Caddy/Node are first-class.

## Why three stages instead of one?

See [ARCHITECTURE.md](ARCHITECTURE.md) — short version: the install phase
needs to make irreversible disk decisions, the bootstrap phase needs
network + idempotency, and the day-2 phase needs to be re-runnable.
Mashing them into one would cost reproducibility *and* operability.

## Why CasaOS *and* Cockpit?

They solve different problems:

- **CasaOS**: "I want to click an app icon and have it run."
- **Cockpit**: "I want to manage system-level stuff (storage, services,
  Samba shares) from a browser."

Cockpit is also where the 45Drives `cockpit-file-sharing` module lives,
which is the cleanest UI for SMB+NFS user/group/permission management.

CasaOS's built-in file-sharing app is **disabled** in HomeOS to avoid two
tools fighting over `/etc/samba/smb.conf`.

## Can I run this on a Raspberry Pi?

Not the current arm64 ISO. Pis don't use UEFI — they have their own
boot path (`config.txt`, kernel + initrd directly from FAT32). A
Pi-specific image is on the future-work list.

For x86_64 mini PCs (N100, N305, NUC, etc.), HomeOS is the right tool.

## Why no LetsEncrypt?

Because then you'd need a public domain, public DNS, and either port
forwards or a DNS-01 ACME provider. None of that is needed when Tailscale
already gives you valid `*.ts.net` certs for free over a private mesh.

You **can** add LetsEncrypt manually — Caddy supports it natively. Edit
`/etc/caddy/Caddyfile` and add an `email` directive plus a public hostname
block. But the default has zero public exposure, which is the better
posture for a home box.

## How do I share access with my family?

Two ways:

1. **Tailscale**: invite them to your tailnet. They get the same `*.ts.net`
   hostnames. Use Tailscale ACLs to restrict what they can reach.
2. **LAN only**: they can hit `http://<box-ip>:<port>` directly.

For Jellyfin specifically, you'd want to set
`JELLYFIN_PublishedServerUrl=https://jelly.homeos.<tailnet>.ts.net` so the
mobile apps connect via Tailscale.

## How do I update Debian itself?

Debian security pocket auto-updates daily via `unattended-upgrades`.

For full distribution upgrades:

```bash
sudo apt update
sudo apt full-upgrade
sudo reboot
```

Major version upgrades (13 → 14 when Forky ships): not covered. Plan to
re-flash with a new HomeOS ISO once that's available.

## How do I update HomeOS itself?

Two paths:

1. **Re-flash**: download the new ISO, `dd` to USB, reinstall. The OS disk
   is wiped but `/srv/nas/*` (USB drives) and your tailnet identity are
   untouched. Restic backups can restore container data afterwards.
2. **In-place re-run**:
   ```bash
   cd /opt/homeos
   sudo git pull          # if you cloned it
   sudo homeos config rerun-bootstrap
   ```

Path 2 is the day-to-day path. Path 1 is for major version bumps.

## What happens if my second disk dies?

`vg1` (swap + cache) is on Disk 2. If Disk 2 fails:

- Swap goes away (kernel falls back to no swap).
- LVM cache attached to `vg0/root` shows as broken — read performance drops
  but **data is fine** (cache mode is `writethrough` by default).
- The box keeps running.

Recovery: replace Disk 2, re-run `bootstrap/roles/base/tasks/main.yml` (or
the whole bootstrap), which recreates `vg1` and re-attaches cache.

## What happens if my OS disk dies?

Reinstall from USB. Your USB-attached NAS drives are untouched. Your
Restic backups (if pointed at a NAS drive) are untouched. Your container
config (HA, Jellyfin libraries) lives on `/` so it's gone — restore from
Restic.

This is why the **backup target should always be a NAS USB drive, not the
OS disk**.

## Can I run this in a VM?

Yes. Use:

- 8 GB RAM minimum.
- 60 GB disk 1.
- 20 GB disk 2 (optional).
- Bridged networking (so DHCP works).
- UEFI firmware (for arm64) or BIOS/UEFI (for amd64).

Hardware transcoding obviously doesn't work in a VM unless you pass the
iGPU through (VFIO).

## How do I add a domain name (not just `ts.net`)?

You can layer your own domain on top:

1. Buy a domain.
2. CNAME `home.example.com` → `homeos.<tailnet>.ts.net`.
3. Caddy already serves whatever hostname is requested. Add an entry in
   `/etc/caddy/Caddyfile` for the new hostname pointing at the same
   upstream.

Tailscale won't issue certs for non-`ts.net` names. Either:
- Use HTTP only (insecure on a public domain — don't).
- Add LetsEncrypt for that one hostname (Caddy auto-magic).

## Why pin GitHub tool SHAs?

Because `git clone <repo>` then "build whatever's there" is a supply chain
hole. Pinning to a SHA means:
- The same ISO build reproduces bit-identically.
- An upstream takeover doesn't auto-deploy malicious code on next install.

`make pin-tools` refreshes pins when you want the latest.

## Why are there no automated tests?

There are some — Ansible syntax check, QEMU boot smoke test. What's
**not** automated is end-to-end "did the bootstrap actually finish on real
hardware". That requires a hardware lab, which a home project doesn't
have.

Doctor (`homeos doctor`) is the proxy: it runs after install on real
hardware and exits non-zero on any failure.

## Can I use this commercially?

The code is MIT — yes. The third-party software it bundles
(Jellyfin GPL3, Vaultwarden AGPLv3, etc.) has its own terms; check
each project's license before redistributing.

## I have a question that isn't here

Open an issue: https://github.com/bloodf/homeos/issues. Or ping the
discussion forum.
