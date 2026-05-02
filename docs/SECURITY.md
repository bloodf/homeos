# Security — threat model and hardening

HomeOS is **opinionated about security but pragmatic about first boot**. The
default posture is _secure-by-default-after-step-6_. Until the operator
runs `homeos secure`, password SSH is allowed (so you can upload your first
key over the network).

## Threat model

| Asset                | Threat                                         | Mitigation                                                                                                                                                                                                                |
| -------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Box itself           | Internet brute force on SSH                    | Default deny-inbound UFW; `fail2ban` watches sshd; key-only after `homeos secure`.                                                                                                                                        |
| Box itself           | Lateral movement from a compromised LAN device | Tailscale fully trusted, LAN restricted to listed ports only.                                                                                                                                                             |
| Admin account        | Password reuse                                 | Default `admin/homeos` is **expired** at install — first SSH login forces change. After `homeos secure`, password is locked.                                                                                              |
| Admin account        | Privilege escalation                           | `admin` has `NOPASSWD:ALL` sudo. This is a deliberate trade-off — the box is single-tenant. Don't multi-user it.                                                                                                          |
| Service traffic      | LAN sniffing                                   | All web UIs reachable on Tailscale use Tailscale ACME-equivalent TLS (`ts.net` certs). LAN access is per-IP, no certs.                                                                                                    |
| Public exposure      | DNS leak / port forward attack                 | No public DNS, no LetsEncrypt account, no router port forwards required.                                                                                                                                                  |
| Stack containers     | Unauthenticated APIs (HA, Jellyfin)            | Caddy in front; access control via Tailscale ACL or service-native auth.                                                                                                                                                  |
| Secrets              | Accidental commit                              | Secrets live in `~admin/.config/homeos/secrets.env` (mode 600), never in git. Installers that ask for API keys hide input and do not print secret prefixes.                                                               |
| Audit replay         | Secret-bearing replay payload exposure         | Public JSONL is redacted and mode 0644 by design; replay sidecars live under `/var/lib/homeos/audit-replay` as root:root 0700 with 0600 files and a 90-day prune timer.                                                   |
| Docker control plane | Container UI can mutate the host Docker daemon | Cosmos uses `/var/run/cosmos-docker.sock` audit shim instead of the host socket. Dockge and Watchtower still need direct Docker socket access; keep them tailnet/local only and treat compromise as host-root equivalent. |
| Backups              | Single-point-of-failure                        | Restic to local USB. Offsite backup is opt-in through `homeos install offsite-backup`.                                                                                                                                    |
| Supply chain         | Malicious upstream                             | Pinned commit SHAs for GitHub tools, signed apt repos for Docker/Tailscale/Caddy/Node/Trivy, pinned SHA256 manifest for Debian netinst, SHA256 files for release ISOs.                                                    |

## Default firewall (UFW)

Default: `deny incoming`, `allow outgoing`.

Tailscale interface (`tailscale0`) is **fully trusted** — no per-port rules.

LAN allowlist (TCP):

- 22 (SSH)
- 80 / 443 (Caddy)
- 81 (CasaOS UI)
- 445 (Samba SMB)
- 139 (Samba NetBIOS session)
- 2049 (NFS)
- 8123 (Home Assistant)
- 8096 (Jellyfin)
- 8222 (Vaultwarden)
- 9090 (Cockpit)

LAN allowlist (UDP):

- 137 / 138 (Samba browse)
- 2049 (NFS)
- 5353 (mDNS)
- 1900 (SSDP / DLNA)
- 7359 (Jellyfin auto-discovery)

Edit `bootstrap/vars/main.yml` → `firewall_allow_tcp` / `firewall_allow_udp`,
then `homeos config rerun-bootstrap`.

## SSH posture

`/etc/ssh/sshd_config.d/99-homeos.conf`:

| Directive                      | Initial | After `homeos secure` |
| ------------------------------ | ------- | --------------------- |
| `PasswordAuthentication`       | `yes`   | `no`                  |
| `PermitRootLogin`              | `no`    | `no`                  |
| `KbdInteractiveAuthentication` | `no`    | `no`                  |
| `MaxAuthTries`                 | `4`     | `4`                   |
| `LoginGraceTime`               | `30`    | `30`                  |

## The `homeos secure` flow

```
sudo homeos secure
```

Refuses to run unless:

1. `~admin/.ssh/authorized_keys` is non-empty.
2. The file contains at least one recognizable OpenSSH public key.
3. `sshd -t` accepts the config after the password-auth change.
4. `sshd -T` reports effective `pubkeyauthentication yes` for `admin`.
5. `sshd -T` reports an `authorizedkeysfile` path that includes `.ssh/authorized_keys`.

If those checks pass, `homeos secure`:

1. Repairs `~admin/.ssh` ownership/mode and `authorized_keys` ownership/mode.
2. Sets `PasswordAuthentication no`.
3. Restarts SSH.
4. Locks the `admin` password with `passwd -l admin`.

After `homeos secure`, the only way into the box is:

- SSH with `admin`'s key.
- `tailscale ssh` from another Tailscale node (subject to Tailscale ACLs).
- Console access (boot from USB, `passwd -u`).

## Secrets management

`homeos config secrets set KEY=VALUE` writes to
`~admin/.config/homeos/secrets.env` with mode 600. The file is sourced by
`~admin/.zshrc`.

- Never committed to git.
- Mode 600 — only `admin` can read.
- Re-readable on every interactive shell — reconnect SSH after `set` to pick
  up new values.
- `homeos config secrets list` shows keys, never values.

Rotate by re-running `set` with a new value. Old value is overwritten.

## Audit logs and replay sidecars

- `/var/log/homeos-audit.jsonl` is public-to-local-users mode 0644. It is
  intentionally redacted: command labels, verdicts, choices, hashes, and sidecar
  IDs only.
- `/var/lib/homeos/audit-replay/` is root:root mode 0700. Sidecars are written
  mode 0600 and may contain argv/environment replay material needed to rerun a
  gated operation.
- `homeos-audit-prune.timer` removes sidecars after 90 days. The JSONL audit log
  rotates weekly for 520 rotations, matching the long-lived accountability log.

## Docker socket, privileged containers, and host mounts

Docker socket access is equivalent to host-root control. v0.8 reviewed every
compose template and keeps these explicit exceptions:

| Stack                 | Sensitive access                                                                             | Reason / mitigation                                                                                                                                      |
| --------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cosmos                | `privileged: true`; shim socket mounted as `/var/run/docker.sock`; `/srv/cosmos` data/config | Cosmos is an optional container manager. It no longer receives the host socket directly; mutating Docker API calls pass through the HomeOS audit shim.   |
| Portal / Homepage     | Host Docker socket mounted with a read-only bind flag                                        | Homepage needs Docker metadata for widgets. The Docker API itself is still powerful even through a read-only bind, so Portal remains tailnet/local only. |
| Portal / Dockge       | Host Docker socket; `/opt/stacks`; `/srv/portal/dockge`                                      | Required to manage compose stacks. Treat Dockge admin access as host-root equivalent.                                                                    |
| Portal / ttyd         | `~admin`, `/opt/tools:ro`, secrets file read-only                                            | Optional web terminals are loopback-bound behind Caddy. Secrets are mounted read-only but are visible inside those containers; trusted admins only.      |
| Portal / Filebrowser  | `/srv` and admin home bind mounts                                                            | Intended file manager for local admin data; exposed only behind local/Tailscale Caddy routes.                                                            |
| Watchtower            | Host Docker socket                                                                           | Required for label-scoped image updates. Critical stacks are labeled out of automatic updates.                                                           |
| Home Assistant        | `privileged: true`; host network; `/run/dbus:ro`                                             | Needed for common HA integrations and discovery. Exposed on LAN/Tailnet only.                                                                            |
| Jellyfin              | Optional `/dev/dri` GPU device; media read-only                                              | Device is rendered only when present; media library mount is read-only.                                                                                  |
| Monitoring / Scrutiny | `privileged: true`, `SYS_RAWIO`, `SYS_ADMIN`, `/run/udev:ro`, `/dev/sda`                     | Optional SMART monitoring requires raw disk access; install only on trusted boxes.                                                                       |

Accepted residual risk: anyone who compromises a Docker-control UI, a privileged
container, or a container with the Docker socket can likely take over the host.
HomeOS mitigates exposure with UFW, Tailscale-first routing, loopback-only
service binds behind Caddy where practical, audit visibility where practical,
and clear opt-in installers rather than sandboxing Docker itself.

## Image tag policy

Some upstreams are intentionally tracked by moving tags because the home-server
UX values current applications and Watchtower can update only by tag. Critical
stacks such as Home Assistant and Vaultwarden are excluded from automatic
Watchtower updates. `latest`, `stable`, `main`, and similar moving tags are
accepted only for these compose templates and installer-generated optional
stacks; review release notes/changelogs before manually updating critical
services.

## Auto-updates

- **Debian security**: `unattended-upgrades` enabled, **security pocket only**
  (no broad upgrades). Daily.
- **Docker images**: `watchtower` runs daily at 04:00 BRT, updates only
  containers labeled `com.centurylinklabs.watchtower.enable=true`. Critical
  containers (Home Assistant, Vaultwarden) are excluded — manual upgrades
  only.
- **Apt full-upgrade**: never automatic. Run manually:
  ```
  sudo apt update && sudo apt full-upgrade
  ```

## Supply chain pins

| Source                                      | Pin                                                                      | Verification                                                                                                           |
| ------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Debian netinst                              | `13.4.0` plus `build/debian-base-isos.sha256`                            | Local pinned SHA256 and official upstream `SHA256SUMS` must both match.                                                |
| Builder image                               | `debian:trixie-slim` in `build/Dockerfile`                               | OCI labels document purpose/source; Debian package names are installed from current trixie apt metadata at build time. |
| Docker apt                                  | `download.docker.com`                                                    | Docker Inc. signed key.                                                                                                |
| Tailscale apt                               | `pkgs.tailscale.com`                                                     | Tailscale signed key.                                                                                                  |
| Caddy apt                                   | `dl.cloudsmith.io/public/caddy/stable`                                   | Cloudsmith signed key.                                                                                                 |
| NodeSource apt                              | `deb.nodesource.com/node_24.x`                                           | NodeSource signed key.                                                                                                 |
| Node version                                | `node_major: "24"`                                                       | enforced by `apt install nodejs`.                                                                                      |
| GitHub tools                                | commit SHA per repo plus `hermes_agent_ref` in `bootstrap/vars/main.yml` | `make pin-tools` resolves each configured GitHub repo `HEAD` and refuses partial writes.                               |
| AI CLIs (npm/corepack/brew)                 | moving package channel at install time                                   | Registry/tap transport trust; recorded as accepted moving-channel risk.                                                |
| AI CLIs and shell tools from installer URLs | reviewed URL, optional SHA256 field for `ai_clis_curl` entries           | Download to a temp file before execution; TLS-only where upstream does not publish stable checksums.                   |

Internal ISO integrity note: `build/repack-iso.sh` regenerates Debian installer
`md5sum.txt` because that file is a Debian ISO compatibility artifact. It is not
treated as a cryptographic security boundary; release verification relies on the
external `.iso.sha256` assets and the pinned base ISO SHA256 manifest.

Release artifacts include `*.iso.sha256`. Verify after download with:

```bash
sha256sum -c homeos-debian-13.4-amd64.iso.sha256
```

`make pin-tools` rewrites GitHub tool SHAs from upstream `HEAD`, including the
dedicated Hermes agent pin. Run before tagging a release. Release builds verify
committed pins with `build/refresh-pins.sh --check`; they do not refresh pins
while building a tag.

## What HomeOS does **not** protect against

- **Physical access.** Disk is unencrypted (LUKS would block headless
  reboots). An attacker with the box can mount `/dev/vg0/root` from a rescue
  USB and read everything.
- **Compromised admin laptop.** If your SSH key is exfiltrated, `homeos
secure` can't help.
- **Malicious upstream tag.** Pinned SHAs help, but signed releases would be
  better. Tracking issue.
- **Container escapes.** Standard Docker isolation only. No gVisor / Kata
  Containers.

## Recovery

Locked yourself out? Boot the same HomeOS USB, pick "Rescue" from grub, mount
`/dev/vg0/root`, then:

```bash
chroot /target
passwd -u admin
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-homeos.conf
exit
reboot
```

## Future work

- Offsite backups (rclone to S3-compatible target).
- Tailscale ACL templates for sharing the box with family without giving
  full access.
- Sigstore-style signed release manifests for `make iso` reproducibility.
- Optional LUKS for disk encryption when hardware key is present (TPM /
  Yubikey).

## Additional supply-chain and rollback hardening

- Debian base ISO downloads now fetch `SHA256SUMS` plus `SHA256SUMS.sign` and verify the signed manifest with a vendored Debian CD signing keyring before comparing the committed ISO checksum pin.
- CasaOS distinguishes the pinned `casaos_version` from installer trust. Operators can set `casaos_installer_sha256` for verified installs. Without a checksum, the default is fail-closed; set `casaos_allow_unverified_installer: true` only to explicitly accept the TLS-only installer risk.
- Docker stack updates record pre-update image IDs and repo digests under `/var/lib/homeos/stack-digests`. Rollback can pin generated compose files to recorded immutable digests when all services have repo digests. Rollback does not revert volumes, databases, app migrations, or non-image compose changes.
