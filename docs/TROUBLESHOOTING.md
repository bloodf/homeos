# Troubleshooting

When the box doesn't behave, check these in order.

## Install (Stage A) issues

### Installer doesn't boot

- **Symptom**: USB shows up in BIOS but "no bootable device" / "operating
  system not found".
- **Cause**: USB was written in ISO mode (Rufus default) instead of DD mode.
- **Fix**: Re-flash with `dd` (Linux/macOS) or Rufus's "DD Image" mode.

### Installer hangs at "Detecting hardware"

- **Cause**: missing firmware for your NIC/Wi-Fi/SCSI.
- **Fix**: Wired Ethernet. The netinst ISO ships with the common firmware
  but exotic NICs may need `firmware-*` packages. Workaround: use a USB
  Ethernet adapter for install, swap to onboard after.

### Install completes but reboots into "no bootable device"

- **Cause**: USB still plugged, BIOS booting USB again instead of the disk.
- **Fix**: Pull the USB at the reboot prompt.

### Disks are wrong (data loss risk!)

- **Symptom**: installer wiped the wrong disk.
- **Prevention**: HomeOS preseed targets `/dev/sda`. Disconnect any other
  bootable disks before installing. The preseed will not prompt before
  formatting. The optional `/dev/sdb` cache/swap step skips mounted media and
  ISO/UDF devices so the USB installer is not treated as a cache disk, but you
  should still disconnect disks you do not want touched.

### Installer reports `admin` is a reserved username

HomeOS intentionally asks Debian Installer to create a temporary `diadmin`
account because `admin` is reserved by Debian's user setup component. The
`late_command` then renames `diadmin` to `admin`, renames or selects the
`admin` group, repairs `/home/admin` ownership, installs sudoers, optionally
copies baked SSH keys, and expires the default password. If you see a reserved
username error, verify the ISO contains the current `preseed/preseed.cfg` and
not an older preseed that requested `passwd/username string admin` directly.

## First boot (Stage B) issues

### `homeos-firstboot.service` never finishes

```bash
sudo systemctl status homeos-firstboot.service
sudo tail -n 200 /var/log/homeos-bootstrap.log
sudo journalctl -u homeos-firstboot.service -e
```

Common causes:

- **No internet.** The bootstrap pulls apt, npm, brew, Docker images. Check
  `ip a`, `ping deb.debian.org`, `curl -I https://github.com`.
- **DNS broken.** Check `/etc/resolv.conf`. If `systemd-resolved` is the
  authority, `resolvectl status`.
- **GitHub rate limit.** Tool clones can fail. Re-run:
  `sudo homeos config rerun-bootstrap`.
- **A specific role failed.** The log shows the failed task. Fix the
  underlying issue and re-run. `/var/lib/homeos/bootstrapped` is created only
  after a successful play; if it is absent, `homeos-firstboot.service` will
  retry on the next boot.

### `homeos-firstboot.service` succeeded but services aren't running

```bash
homeos status
homeos doctor
```

`doctor` exits non-zero on the first failure. Pick services from there:

```bash
sudo systemctl status caddy
sudo journalctl -u caddy -e
docker ps -a              # show stopped containers
docker logs <container>
```

### Network-online wait

Stage B has `After=network-online.target` and the playbook also waits up to
120 seconds for outbound HTTPS to `deb.debian.org:443` before roles start. On
some hardware the network isn't ready when systemd thinks it is. Workaround:

```bash
sudo systemctl edit homeos-firstboot.service
# add:
# [Service]
# ExecStartPre=/bin/sleep 30
sudo systemctl daemon-reload
sudo systemctl restart homeos-firstboot.service
```

## SSH / `homeos secure` issues

### Can't SSH in after `homeos secure`

```
Permission denied (publickey).
```

You locked password auth before key auth was actually working. Recovery:

1. Boot the same HomeOS USB.
2. Pick "Rescue" from grub.
3. Mount root: `mount /dev/vg0/root /mnt`.
4. `chroot /mnt`.
5. Edit `/etc/ssh/sshd_config.d/99-homeos.conf` → `PasswordAuthentication yes`.
6. `passwd -u admin`.
7. Reboot.

### Default password doesn't work

The default `admin/homeos` password is **expired** at install. The first
SSH login forces a change. Symptoms:

- "It is required to change your password immediately."
- After change, you're at a shell.

If you typed your new password wrong: SSH back in with the old one (`homeos`),
the change prompt fires again.

### `homeos secure` refuses to run

```
no /home/admin/.ssh/authorized_keys — upload your pubkey first
```

Fix:

```bash
# from your laptop:
scp ~/.ssh/id_ed25519.pub admin@<ip>:.ssh/authorized_keys

# verify on the box:
ssh admin@<ip>
chmod 600 ~/.ssh/authorized_keys
```

```
no recognizable key line
```

The file exists but doesn't look like SSH keys. Open it and check for lines
containing `ssh-rsa`, `ssh-ed25519`, `ssh-dss`, or `ecdsa-sha2-*`. `homeos
secure` also repairs ownership/modes and refuses to proceed if the resulting
`sshd -t` or effective public-key-auth check fails.

## Tailscale issues

### `homeos config net tailscale-up` hangs

- **Cause**: no internet route to Tailscale's coordination server.
- **Fix**: verify outbound HTTPS works:
  `curl -I https://login.tailscale.com`.

### Service hostnames don't resolve

```
ssh: Could not resolve hostname jelly.homeos.<tailnet>.ts.net
```

- Verify Tailscale is up: `tailscale status`.
- MagicDNS must be enabled in your tailnet: https://login.tailscale.com/admin/dns.
- The hostname format is `<service>.homeos.<tailnet>.ts.net` (note the
  literal `homeos.` prefix — that's the box's tailnet hostname).

### Caddy returns 502

- The upstream service is down. Check `docker ps` or `homeos status`.
- The Caddyfile points at the wrong port. `cat /etc/caddy/Caddyfile`.
- Tailscale cert provisioning failed. `journalctl -u caddy -e`.

## NAS issues

### `homeos config nas add` fails with "no LABEL"

The drive doesn't have a filesystem label. Set one and retry:

```bash
sudo umount /dev/sdc1
sudo e2label /dev/sdc1 mylabel       # ext4
# or:
sudo xfs_admin -L mylabel /dev/sdc1  # xfs
sudo btrfs filesystem label /dev/sdc1 mylabel  # btrfs
```

### Mount shows up but is empty

The filesystem is fine but the mount happened over an empty mount point.
Check `findmnt /srv/nas/<label>`. If the device shown is the actual
partition, but the directory is empty, you may have copied data into
`/srv/nas/<label>` *before* the mount unit kicked in. Unmount, move the
strays, remount.

### SMB share invisible from Windows

```bash
sudo systemctl restart smbd nmbd
```

Windows requires NetBIOS browse (UDP 137/138). Verify they're allowed:

```bash
sudo ufw status verbose | grep -E '137|138'
```

## Docker stack issues

### A stack won't start

```bash
homeos config stack logs <name>
# or:
docker logs $(docker ps -aq --filter "name=<container>" | head -1)
```

Common causes:
- Bind-mount source doesn't exist. `ls -la /srv/<service>`.
- Port already in use. `sudo ss -tulnp | grep :<port>`.
- Hardware passthrough missing (`/dev/dri` for Jellyfin).

### Watchtower broke a service

Watchtower opt-in is label-based. Critical services (HA, Vaultwarden) are
explicitly excluded. If a non-critical service breaks after auto-update:

```bash
docker pull <image>:<previous-tag>
homeos config stack down <name>
# edit /opt/stacks/<name>/docker-compose.yml to pin :<previous-tag>
homeos config stack up <name>
```

## GPU / Jellyfin transcoding

### `vainfo` shows no driver

```bash
ls -la /dev/dri/
# you should see card0 + renderD128

groups admin
# should include 'render' and 'video'

vainfo
# look for "vainfo: Driver version: Intel iHD ..."
```

If `iHD` is missing on a Gen 9+ Intel iGPU, install the non-free driver:

```bash
sudo apt install intel-media-va-driver-non-free
sudo reboot
```

### Jellyfin transcodes on CPU instead of QSV

In Jellyfin admin UI: **Playback → Transcoding → Hardware acceleration →
Intel QuickSync (QSV)**. Enable everything (HEVC, AV1, etc.).

The Jellyfin container needs `/dev/dri` and `group_add: [render]` in its
compose. They're in the default `bootstrap/templates/jellyfin-compose.yml.j2` —
verify if you've customized.

## Bootstrap log location

```bash
sudo less /var/log/homeos-bootstrap.log
sudo journalctl -u homeos-firstboot.service
```

## Diagnostic dump

For bug reports:

```bash
homeos status > /tmp/homeos-status.txt
homeos doctor 2>&1 | tee /tmp/homeos-doctor.txt
sudo tail -n 500 /var/log/homeos-bootstrap.log > /tmp/homeos-bootstrap.txt
sudo systemctl status caddy docker cockpit.socket casaos tailscaled \
  smbd nfs-kernel-server > /tmp/homeos-services.txt
```

Attach those four files to the issue.

## Unified diagnostics and logs

Start with:

```bash
homeos diag
homeos log firstboot --lines 200
homeos log backup --lines 100
homeos log docker --lines 100
homeos log stack:jellyfin --lines 100
```

Raw fallbacks remain useful if the CLI itself is unavailable:

```bash
sudo journalctl -u homeos-firstboot.service -e
sudo tail -n 200 /var/log/homeos-bootstrap.log
sudo tail -n 100 /var/log/homeos-backup.log
```

## Recover from a bad stack image update

List recorded pre-update image snapshots and roll back to the latest safe digest set:

```bash
homeos config stack digests <name>
sudo homeos config stack rollback <name>
```

HomeOS writes a compose backup next to `/opt/stacks/<name>/docker-compose.yml` before rewriting images. Rollback fails closed when a service lacks an immutable repo digest.
