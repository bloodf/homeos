# Install Walkthrough

End-to-end install on real hardware, from `dd` to `homeos doctor` green.

## Prerequisites

### Build host
- Docker (or OrbStack on macOS). Tested on macOS 13+, Ubuntu 22.04+, Debian 12+.
- ~2 GB free RAM during build, ~3 GB free disk for `build/cache/` + `dist/`.
- Network access for the upstream Debian ISO download (~750 MB) and the
  GitHub API (for `pin-tools`).

### Target hardware (recommended)
- x86_64 with EFI **or** legacy BIOS (the ISO is hybrid).
- Two SATA/NVMe disks: Disk 1 ≥ 60 GB (OS + apps), Disk 2 ≥ 20 GB (swap + cache).
  *Single-disk install also works — the second-disk cache step is `|| true`.*
- A modern Intel iGPU (Gen 9+) for Jellyfin hardware transcoding (optional but
  recommended). AMD GPUs work via VAAPI; Nvidia needs the proprietary stack —
  out of scope.
- DHCP-capable wired network at first boot.
- USB stick ≥ 4 GB for the installer.

### Anything you want to share via NAS
- Format the USB drives ext4 / xfs / btrfs with **labels** (`mkfs.ext4 -L mymedia ...`).
- HomeOS won't touch them during install — they're picked up at runtime via
  `homeos config nas add`.

## 1. Get the ISO

Either:

**A. Download from a GitHub release**

```bash
curl -fSLO https://github.com/bloodf/homeos/releases/latest/download/homeos-debian-13.4-amd64.iso
curl -fSLO https://github.com/bloodf/homeos/releases/latest/download/homeos-debian-13.4-amd64.iso.sha256
sha256sum -c homeos-debian-13.4-amd64.iso.sha256
```

**B. Build it yourself** (recommended if you want to bake in your SSH key)

```bash
git clone https://github.com/bloodf/homeos
cd homeos

# optional — skip for a public/shared distro
# Private builds bake this key into /home/admin/.ssh/authorized_keys.
cp ~/.ssh/id_ed25519.pub secrets/authorized_keys

make iso
# → dist/homeos-debian-13.4-amd64.iso (+ .sha256)
```

For arm64:

```bash
make ARCH=arm64 iso
```

## 2. Flash to USB

> ⚠️ **`dd` writes to whichever device you tell it to. Double-check the path.**

### macOS

```bash
diskutil list                                # find the right /dev/diskN
diskutil unmountDisk /dev/diskN
sudo dd if=dist/homeos-debian-13.4-amd64.iso \
        of=/dev/rdiskN bs=4m status=progress
sync
diskutil eject /dev/diskN
```

### Linux

```bash
lsblk                                        # find /dev/sdX
sudo umount /dev/sdX*                        # unmount any auto-mounted partition
sudo dd if=dist/homeos-debian-13.4-amd64.iso \
        of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

### Windows
Use [Rufus](https://rufus.ie/) in **DD Image** mode. Do NOT use ISO mode —
it will rewrite the boot record and break the unattended install.

## 3. First boot — install phase

1. Plug the USB into the target box. Boot it. Set USB as first boot device
   in firmware if needed.
2. The installer auto-selects the unattended menu entry. Walk away. Total
   install time: 8–20 minutes depending on disk + network.
3. The box reboots, removes the USB, and boots into Debian.
4. **Stage B** — `homeos-firstboot.service` runs once, applying the Ansible
   playbook. This pulls apt packages, npm packages, brew formulas, Docker
   images, and clones 10 GitHub tools. Total time: 20–40 minutes on a
   100 Mbit/s connection.

You don't need to do anything during Stage B. The box is reachable via SSH
the moment Stage A finishes — Stage B runs in the background.

## 4. First SSH login

Find the box's DHCP-assigned IP (check your router or run `ssh admin@homeos.local`
if mDNS is working).

```bash
ssh admin@<ip>
# public ISO password: homeos
# you will be FORCED to change the password — pick something strong, you'll
# only use it for the next 60 seconds.
```

Private ISOs with `secrets/authorized_keys` baked in can use key-based SSH
immediately, but the fallback `homeos` password is still expired until changed.

After the password change you're at a shell. The bootstrap may still be
running in the background:

```bash
sudo tail -f /var/log/homeos-bootstrap.log
# wait for: ==== bootstrap complete <timestamp> ====
```

If you don't see the "complete" line within an hour, run
`sudo systemctl status homeos-firstboot.service` and check
`docs/TROUBLESHOOTING.md`.

## 5. Upload your SSH pubkey

```bash
# from your laptop, after Stage A finishes:
scp ~/.ssh/id_ed25519.pub admin@<ip>:.ssh/authorized_keys

# back on the server:
ssh admin@<ip>
chmod 600 ~/.ssh/authorized_keys
```

## 6. Lock things down — `homeos secure`

> Only run this *after* you've confirmed key-based SSH works. Once secured,
> password authentication is disabled and the admin password is locked. If
> your key isn't working, you'll be locked out.

```bash
# verify key auth works first — open a SECOND terminal:
ssh admin@<ip>     # should NOT prompt for password

# in your original terminal:
sudo homeos secure
```

This:
- Refuses to run if `~/.ssh/authorized_keys` is empty or has no recognizable
  key line.
- Repairs `~/.ssh` and `authorized_keys` ownership/modes for `admin`.
- Sets `PasswordAuthentication no` in `/etc/ssh/sshd_config.d/99-homeos.conf`.
- Validates the new sshd config with `sshd -t` and confirms effective
  public-key auth plus `.ssh/authorized_keys` lookup with `sshd -T` before
  restarting.
- Locks the admin password (`passwd -l admin`).

Recovery if you lock yourself out: boot from the USB again, edit
`/etc/ssh/sshd_config.d/99-homeos.conf` from a recovery shell, run
`passwd -u admin`, reboot.

## 7. Join your tailnet

```bash
# get a one-time auth key from https://login.tailscale.com/admin/settings/keys
sudo homeos config net tailscale-up --auth-key tskey-auth-...
# or interactive:
sudo homeos config net tailscale-up
# (paste the URL it prints into your browser to authorize)
```

After this:
- The box is reachable at `homeos.<your-tailnet>.ts.net` from any device on
  your tailnet.
- Caddy automatically gets Tailscale-issued certs for the per-service
  hostnames (`ha.homeos.<tailnet>.ts.net`, `jelly.<tailnet>.ts.net`, etc.).
- `tailscale ssh` works in addition to regular SSH.

## 8. Add NAS drives

For each USB drive you want to share:

```bash
sudo homeos config nas add /dev/sdc1
# → mounts at /srv/nas/<label>, exports via Samba (//homeos/<label>)
#   and NFS (/srv/nas/<label>).
```

The Cockpit UI at `https://homeos.<tailnet>.ts.net:9090/file-sharing` lets you
manage permissions per share.

See [NAS.md](NAS.md) for the full workflow.

## 9. Configure secrets for AI CLIs

```bash
sudo homeos config secrets set ANTHROPIC_API_KEY=<anthropic-key>
sudo homeos config secrets set OPENAI_API_KEY=<openai-key>
sudo homeos config secrets set GOOGLE_API_KEY=<google-key>
sudo homeos config secrets set CURSOR_API_KEY=<cursor-key>
# etc.
```

These land in `~/.config/homeos/secrets.env` (mode 600) and are sourced by
the admin user's zshrc. Reconnect SSH to pick them up.

## 10. Verify everything

```bash
homeos doctor
# expect: ALL OK
```

If anything is red, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## 11. Optional — apps

```bash
# bring up a stack
homeos config stack up jellyfin

# follow logs
homeos config stack logs jellyfin

# update later
homeos config stack update jellyfin
```

CasaOS web UI at `https://casa.homeos.<tailnet>.ts.net` lets you install
extra apps via its catalog. It's configured to **not** manage Samba/NFS —
that's Cockpit's job.

## You're done

The box is now:
- SSH-only, key auth only
- Reachable on your tailnet by hostname
- Backing itself up nightly to `/srv/nas/<your-backup-label>` (after you set
  the target with `homeos config backup target set`)
- Auto-applying Debian security updates
- Auto-updating Docker images on labeled stacks daily at 04:00 BRT
- Reading every AI CLI from your secrets store
