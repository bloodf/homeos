# Architecture

How the three stages fit together, why each choice was made, and where to
look when things go wrong.

## High-level flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage A — Custom preseed netinst ISO                            │
│                                                                 │
│   debian-13.4.0-amd64-netinst.iso  (upstream, 754 MB)           │
│   + preseed/preseed.cfg            → embedded into initrd       │
│   + preseed/grub.cfg               → boot/grub/grub.cfg         │
│   + preseed/isolinux.cfg           → isolinux/isolinux.cfg      │
│   + bootstrap/                     → /cdrom/homeos/bootstrap/   │
│   + secrets/authorized_keys        → /cdrom/homeos/secrets/     │
│         ↓ xorriso repack                                        │
│   homeos-debian-13.4-amd64.iso     (~941 MB)                    │
└─────────────────────────────────────────────────────────────────┘
                            ↓ dd to USB, boot target
┌─────────────────────────────────────────────────────────────────┐
│ debian-installer                                                │
│   • partitions disks (LVM, ext4)                                │
│   • installs base + ssh-server + ansible + git + curl           │
│   • runs late_command:                                          │
│       - copies authorized_keys (if present)                     │
│       - expires admin password (`chage -d 0`)                   │
│       - copies /cdrom/homeos → /opt/homeos                      │
│       - enables homeos-firstboot.service                        │
│       - sets up /dev/sdb LVM (vg1: swap + cache)                │
│   • reboots                                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓ first boot
┌─────────────────────────────────────────────────────────────────┐
│ Stage B — homeos-firstboot.service                              │
│   ExecStartPre: ansible-galaxy collection install -r ...        │
│   ExecStart:    ansible-playbook -i localhost, -c local         │
│                 /opt/homeos/bootstrap/install.yml               │
│                                                                 │
│   • runs roles in order (see BOOTSTRAP.md)                   │
│   • logs to /var/log/homeos-bootstrap.log                       │
│   • on success: touch /var/lib/homeos/bootstrapped              │
│                 systemctl disable homeos-firstboot.service      │
└─────────────────────────────────────────────────────────────────┘
                            ↓ box is fully configured
┌─────────────────────────────────────────────────────────────────┐
│ Stage C — homeos CLI (/usr/local/bin/homeos)                    │
│   day-2 ops: status, doctor, secure, config {nas|stack|net|     │
│              secrets|backup|rerun-bootstrap}                    │
└─────────────────────────────────────────────────────────────────┘
```

## Why three stages

| Concern                    | Solution                                  | Why not the obvious alternative                                                                                                  |
| -------------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Reproducible install image | Stage A (preseed ISO)                     | An "install Debian, then run a script" approach loses reproducibility — the install order matters for partition layout.          |
| Unattended                 | Preseed answers + auto-boot grub/isolinux | Cloud-init doesn't apply: cloud-init runs _after_ install. We need answers _during_ install.                                     |
| First-boot heavy lifting   | Stage B (Ansible)                         | Doing it in `late_command` would block reboot for 30 min and run with no network if cdrom is the only mount.                     |
| Idempotent reconfig        | Ansible playbook                          | Shell scripts make this hard — Ansible's `state: present` semantics mean `homeos config rerun-bootstrap` is safe to run anytime. |
| Day-2 ergonomics           | Stage C (`homeos` CLI)                    | Forcing operators to remember Ansible role tags is hostile. The CLI hides the playbook behind verbs they actually use.           |

## Stage A — repack-iso.sh internals

```bash
xorriso -osirrox on -indev <upstream.iso> -extract / $WORK/extract
# unpacks every file from the upstream ISO into a writable tree.

gunzip -c $EXTRACT/install.amd/initrd.gz | cpio -id        # unpack initrd
cp preseed/preseed.cfg preseed.cfg                         # at root
find . | cpio -o -H newc | gzip -9 > $EXTRACT/install.amd/initrd.gz
# repack initrd with preseed.cfg inside.

install -m 644 preseed/grub.cfg     $EXTRACT/boot/grub/grub.cfg
install -m 644 preseed/isolinux.cfg $EXTRACT/isolinux/isolinux.cfg
# our boot configs auto-select the install entry, no menu.

rsync -a bootstrap/ $EXTRACT/homeos/bootstrap/             # whole bootstrap dir
[ -s secrets/authorized_keys ] \
  && cp secrets/authorized_keys $EXTRACT/homeos/secrets/   # baked key (private build)
# OR empty placeholder (public build).

# Regenerate ISO9660 md5sum.txt so debian-installer's integrity check passes.
find $EXTRACT -type f ! -name md5sum.txt -print0 \
  | xargs -0 md5sum > $EXTRACT/md5sum.txt

# Build hybrid (amd64) or EFI-only (arm64) ISO.
xorriso -as mkisofs ... -o $OUT $EXTRACT
```

### Why not `simple-cdd`, `live-build`, or `debian-cd`

These tools are for _building distributions_ — they assume you have a Debian
mirror and want to assemble a custom CD/DVD image. We want to _modify_ an
upstream netinst ISO with three small changes (preseed, boot config, payload).
`xorriso` does that in 50 lines and 90 seconds.

## Preseed.cfg — what it answers

| Section  | What                                                                                      | Why this choice                             |
| -------- | ----------------------------------------------------------------------------------------- | ------------------------------------------- |
| Locale   | `en_US.UTF-8`                                                                             | Default for tooling compatibility           |
| Keyboard | `us`                                                                                      | Owner preference                            |
| Time     | `America/Sao_Paulo`                                                                       | Owner location (Brazil)                     |
| Network  | DHCP, hostname `homeos`                                                                   | Home networks have a DHCP server            |
| Mirror   | `deb.debian.org` (mirror chooser)                                                         | Apt picks a fast mirror automatically       |
| Root     | disabled                                                                                  | Root login forbidden, sudo-only             |
| User     | `admin`, default password `homeos`, expired                                               | Public-distro fallback                      |
| Disk 1   | LVM `vg0/root` with `/boot` ext4                                                          | Headless box doesn't need encryption        |
| Disk 2   | created in `late_command` (vg1: swap + cache)                                             | preseed only handles one disk recipe        |
| Tasks    | `standard, ssh-server`                                                                    | Smallest footprint that boots + lets us SSH |
| Packages | `openssh-server curl ca-certificates gnupg git ansible sudo lvm2 cryptsetup parted rsync` | Minimum to run Stage B                      |

`late_command` runs as the last step of the installer. Ours:

1. Creates `/home/admin/.ssh/`, copies `authorized_keys` if shipped.
2. Runs `chage -d 0 admin` to expire the password (force change on first SSH).
3. Adds `admin ALL=(ALL) NOPASSWD:ALL` in `/etc/sudoers.d/admin`.
4. Copies `/cdrom/homeos` → `/opt/homeos` (so Stage B has its files after USB removal).
5. Installs + enables `homeos-firstboot.service`.
6. If `/dev/sdb` exists: wipes it, creates `vg1`, allocates swap LV (16 GB) and
   cache LV (rest of disk). The `|| true` guard means the install never fails
   on a single-disk box.

## Stage B — Ansible playbook

`bootstrap/install.yml` is a single-play, single-host playbook. Roles run
in order:

```
base → ssh → shell → docker → node → brew → gpu-intel → ai-clis →
github-tools → tailscale → cockpit → casaos → caddy → stacks → portal →
cosmos → nas → backups → homeos-cli → firstboot
```

Each role's `tasks/main.yml` is idempotent. Re-running the play is safe and
expected — `homeos config rerun-bootstrap` does this. See [BOOTSTRAP.md](BOOTSTRAP.md)
for what each role does.

### Why this ordering

- `base` first because UFW + apt baselines must exist before we install
  anything.
- `ssh` second so even if a later role fails the box is still reachable.
- `docker` before `node` and `brew` because some npm packages have
  optional Docker integrations.
- `gpu-intel` before `stacks` (Jellyfin) because Jellyfin's compose file
  references `/dev/dri` and the `render` group.
- `ai-clis` before `github-tools` because some tools use the AI CLIs.
- `tailscale → caddy` because Caddy reads `tailscale status` for cert
  issuance.
- `nas` after `stacks` because Jellyfin reads `/srv/nas/media`.
- `homeos-cli` and `firstboot` last — these are the operator-facing pieces
  and need everything else in place.

## Stage C — homeos CLI

A single-file bash script at `/usr/local/bin/homeos`. Subcommand dispatcher.
See [DAY2.md](DAY2.md) for full reference.

Design rules:

- **No state of its own.** Every operation either edits a file Ansible
  manages or invokes a service. There's no separate config DB.
- **Re-runnable.** Calling `homeos config nas add` twice is a no-op. Calling
  `homeos config rerun-bootstrap` is the recovery story when anything drifts.
- **Verbose.** It prints every command it runs, so you can read the
  implementation without the source code.

## Cosmos Docker socket shim

Cosmos needs Docker API access for its container UI. HomeOS does not mount the
real `/var/run/docker.sock` into Cosmos directly. The `cosmos` role installs
`homeos-cosmos-docker-shim.service`, which listens on
`/var/run/cosmos-docker.sock` and forwards to the real Docker socket. The Cosmos
compose file mounts the shim socket as `/var/run/docker.sock`.

The shim parses repeated non-streaming HTTP request/response pairs on each
Unix-socket connection. Mutating Docker API methods (`POST`, `PUT`, `DELETE`)
against containers, images, networks, and volumes write a redacted audit entry
(`cmd=cosmos:<verb>:<resource>`, `verdict=BYPASS`); request bodies are not
logged. Large uploads, streaming endpoints, unbounded responses, and Docker
hijack/upgrade requests are audited from the already-buffered bytes and then
relayed raw in both directions so those Docker APIs keep working without
buffering the full stream.

## Networking model

Two trust zones:

| Zone                   | What's allowed                                          | Cert source               |
| ---------------------- | ------------------------------------------------------- | ------------------------- |
| LAN (`eth0`)           | UFW-allowed ports only (SSH, HTTP, HTTPS, NAS, web UIs) | self-signed / none        |
| Tailnet (`tailscale0`) | everything                                              | Tailscale ACME-equivalent |

Caddy listens on `:80` and `:443`. For LAN access, hit the IP directly on
the service port. For tailnet access, use the per-service hostname:

- `casa.homeos.<tailnet>.ts.net` → `:81` (CasaOS)
- `ha.homeos.<tailnet>.ts.net` → `:8123` (Home Assistant)
- `jelly.homeos.<tailnet>.ts.net` → `:8096` (Jellyfin)
- `cockpit.homeos.<tailnet>.ts.net` → `:9090` (Cockpit)
- `vault.homeos.<tailnet>.ts.net` → `:8222` (Vaultwarden)

No public DNS, no LetsEncrypt, no port forwards on your router. Tailscale
gives you DNS + valid TLS for free.

## Storage model

| Mount              | Layout                                                              | Comments                                                 |
| ------------------ | ------------------------------------------------------------------- | -------------------------------------------------------- |
| `/`                | LVM `vg0/root` ext4                                                 | Most of Disk 1. Caches OS, /opt/stacks, /srv             |
| `/boot`            | `/dev/sda1` ext4 1 GB                                               | Required for legacy BIOS + simpler than ESP              |
| swap               | LVM `vg1/swap` (16 GB)                                              | Disk 2, dedicated VG                                     |
| cache              | LVM `vg1/cache` attached to `vg0/root` via `lvconvert --type cache` | Speeds up the OS volume — only attached if Disk 2 exists |
| `/srv/nas/<label>` | USB drives, UUID-pinned `systemd.mount`                             | `nofail`, never blocks boot                              |
| `/srv/<service>`   | bind-mount targets for Docker stacks                                | Lives on `/`                                             |

USB drives are **never** repartitioned by HomeOS. We expect them
pre-formatted with labels. `homeos config nas add /dev/sdcN`:

1. Reads UUID + label via `blkid`.
2. Appends to `bootstrap/vars/nas_disks.yml`.
3. Re-runs the `nas` role (writes a `srv-nas-<label>.mount` unit).
4. Reloads Samba + NFS exports.

## Build provenance

| Item           | Pinned                                              | Verified                             |
| -------------- | --------------------------------------------------- | ------------------------------------ |
| Debian netinst | version `13.4.0` in `download-base-iso.sh`          | SHA256 vs official `SHA256SUMS`      |
| Builder image  | `debian:trixie-slim`                                | by-digest possible, currently by tag |
| Node           | `node_major: "24"` in vars/main.yml                 | NodeSource signed apt repo           |
| Docker         | upstream apt repo                                   | Docker Inc. signed apt repo          |
| Tailscale      | `pkgs.tailscale.com`                                | Tailscale signed apt repo            |
| Caddy          | Cloudsmith stable                                   | Cloudsmith signed apt repo           |
| CasaOS         | `casaos_version` in vars/main.yml                   | upstream installer                   |
| GitHub tools   | commit SHA per repo, refreshed via `make pin-tools` | git via HTTPS                        |
| AI CLIs (npm)  | latest at install time                              | npm registry                         |
| AI CLIs (curl) | upstream installer URL                              | TLS only                             |

`make pin-tools` calls the GitHub API to fetch the current `HEAD` SHA for
each entry in `github_tools` and rewrites the `ref:` values in
`bootstrap/vars/main.yml`. Run this before tagging a release for full
build reproducibility.
