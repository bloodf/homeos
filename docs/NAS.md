# NAS — USB drive workflow

HomeOS treats USB drives as runtime additions, not install-time decisions.

## Why this design

- **No surprise wipes.** HomeOS never repartitions a USB drive. Bring your
  data, plug in, mount.
- **Boot-safe.** Every NAS mount is `nofail` — a missing drive never blocks
  boot.
- **Hot-add / hot-remove.** Drive arrives → `homeos config nas add`. Drive
  leaves → `homeos config nas remove`.
- **Cockpit-managed permissions.** The 45Drives `cockpit-file-sharing` module
  owns SMB user/group/share permissions through the web UI.

## Format your drive first (one-time)

```bash
# pick a clean filesystem and a label you'll recognize
sudo mkfs.ext4 -L media /dev/sdc1
# or btrfs:
sudo mkfs.btrfs -L media /dev/sdc1
# or xfs:
sudo mkfs.xfs -L media /dev/sdc1
```

Labels matter. The mount path is `/srv/nas/<label>/`, the SMB share is
`//homeos/<label>`, the NFS export is `/srv/nas/<label>`.

## Add a drive

```bash
sudo homeos config nas add /dev/sdc1
```

This runs `blkid /dev/sdc1`, reads UUID and LABEL, and:

1. Appends to `bootstrap/vars/nas_disks.yml`:
   ```yaml
   nas_disks:
     - uuid: "abcd-1234-..."
       label: "media"
       fs: "ext4"
   ```
2. Re-runs the `nas` Ansible role with tags `nas`, which:
   - Generates `/dev/disk/by-homeos/media` udev symlink.
   - Generates `srv-nas-media.mount` systemd unit (UUID-pinned, `nofail`).
   - Adds `[media]` section to `/etc/samba/smb.conf`.
   - Adds entry to `/etc/exports`.
   - Reloads Samba + NFS.
3. Mounts at `/srv/nas/media/`.
4. Prints: `Added: //homeos/media (SMB) and /srv/nas/media (NFS).`

## List drives

```bash
homeos config nas list
```

Output:

```
LABEL    UUID                  FS    MOUNT             SMB                NFS
media    abcd-1234-...         ext4  /srv/nas/media    //homeos/media     /srv/nas/media
backups  efgh-5678-...         btrfs /srv/nas/backups  //homeos/backups   /srv/nas/backups
```

## Remove a drive

```bash
sudo homeos config nas remove media
```

This:
1. Unmounts `/srv/nas/media/`.
2. Removes the entry from `nas_disks.yml`.
3. Re-runs the `nas` role, which drops the systemd mount unit, removes the
   Samba section, removes the NFS export.
4. Reloads Samba + NFS.

The drive's contents are untouched. You can plug it into another machine and
it just mounts.

## Mount a drive on a client

### macOS Finder

`Cmd-K` → `smb://<box-ip>/<label>` or `smb://homeos.<tailnet>.ts.net/<label>`.

### Linux

```bash
# CIFS / SMB
sudo mount -t cifs //homeos.<tailnet>.ts.net/media /mnt/media \
  -o username=admin,vers=3.0,uid=$(id -u),gid=$(id -g)

# NFS
sudo mount -t nfs homeos.<tailnet>.ts.net:/srv/nas/media /mnt/media
```

### Windows

`\\homeos.<tailnet>.ts.net\media` in Explorer. Authenticate as `admin`.

## SMB users

By default the only SMB user is `admin` (mapped to the Linux `admin` user).

Add SMB users via Cockpit:

1. Open `https://homeos.<tailnet>.ts.net:9090`.
2. **Identities** → add a new user.
3. **File Sharing** → grant the user access to specific shares.
4. Set the SMB password via Cockpit → Identities → Set SMB password.

## NFS access control

`/etc/exports` is generated with LAN-only allowlists by default
(`192.168.0.0/16` and `100.64.0.0/10` for Tailscale). Edit
`bootstrap/templates/exports.j2` for tighter control, then
`homeos config rerun-bootstrap`.

## Sharing rules summary

| Protocol | Auth | Encryption | Default access |
|---|---|---|---|
| SMB | username/password | SMB3 minimum (encrypted in transit) | `admin` only |
| NFS | host-based | none (LAN-trusted only) | `192.168.0.0/16` + Tailscale CIDR |

For untrusted networks, **only** access NAS over Tailscale.

## Backups

Set the backup target to one of your NAS drives:

```bash
sudo homeos config backup target set /srv/nas/backups
```

This initializes a Restic repository at that path. Cron at 02:30 BRT backs up
`/srv`, `/opt/stacks`, and `/home/admin`. See [DAY2.md](DAY2.md) for the full
backup CLI.

## Troubleshooting

- **Drive doesn't appear in `lsblk`** — bad cable / power. Try a different
  USB port or powered hub.
- **`mount: wrong fs type`** — the filesystem on the partition isn't
  recognized. Check `blkid /dev/sdcN`.
- **Missing label** — `homeos config nas add` requires a `LABEL`. Run
  `e2label`, `xfs_admin -L`, or `btrfs filesystem label` to set one.
- **SMB share invisible from Windows** — Windows requires SMB browser
  (UDP 137/138). Verify they're allowed in `homeos status`.
