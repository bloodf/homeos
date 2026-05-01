# Security — threat model and hardening

HomeOS is **opinionated about security but pragmatic about first boot**. The
default posture is *secure-by-default-after-step-6*. Until the operator
runs `homeos secure`, password SSH is allowed (so you can upload your first
key over the network).

## Threat model

| Asset | Threat | Mitigation |
|---|---|---|
| Box itself | Internet brute force on SSH | Default deny-inbound UFW; `fail2ban` watches sshd; key-only after `homeos secure`. |
| Box itself | Lateral movement from a compromised LAN device | Tailscale fully trusted, LAN restricted to listed ports only. |
| Admin account | Password reuse | Default `admin/homeos` is **expired** at install — first SSH login forces change. After `homeos secure`, password is locked. |
| Admin account | Privilege escalation | `admin` has `NOPASSWD:ALL` sudo. This is a deliberate trade-off — the box is single-tenant. Don't multi-user it. |
| Service traffic | LAN sniffing | All web UIs reachable on Tailscale use Tailscale ACME-equivalent TLS (`ts.net` certs). LAN access is per-IP, no certs. |
| Public exposure | DNS leak / port forward attack | No public DNS, no LetsEncrypt account, no router port forwards required. |
| Stack containers | Unauthenticated APIs (HA, Jellyfin) | Caddy in front; access control via Tailscale ACL or service-native auth. |
| Secrets | Accidental commit | Secrets live in `~admin/.config/homeos/secrets.env` (mode 600), never in git. |
| Backups | Single-point-of-failure | Restic to local USB. Offsite is a deliberate follow-up — see "Future work". |
| Supply chain | Malicious upstream | Pinned commit SHAs for GitHub tools, signed apt repos for Docker/Tailscale/Caddy/Node, SHA256 verification on Debian netinst. |

## Default firewall (UFW)

Default: `deny incoming`, `allow outgoing`.

Tailscale interface (`tailscale0`) is **fully trusted** — no per-port rules.

LAN allowlist (TCP):
- 22 (SSH)
- 80 / 443 (Caddy)
- 81 (CasaOS UI)
- 445 (Samba SMB)
- 2049 (NFS)
- 8123 (Home Assistant)
- 8096 (Jellyfin)
- 8222 (Vaultwarden)
- 9090 (Cockpit)

LAN allowlist (UDP):
- 137 / 138 (Samba browse)
- 5353 (mDNS)

Edit `bootstrap/vars/main.yml` → `firewall_allow_tcp` / `firewall_allow_udp`,
then `homeos config rerun-bootstrap`.

## SSH posture

`/etc/ssh/sshd_config.d/99-homeos.conf`:

| Directive | Initial | After `homeos secure` |
|---|---|---|
| `PasswordAuthentication` | `yes` | `no` |
| `PermitRootLogin` | `no` | `no` |
| `KbdInteractiveAuthentication` | `no` | `no` |
| `MaxAuthTries` | `4` | `4` |
| `LoginGraceTime` | `30` | `30` |

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

| Source | Pin | Verification |
|---|---|---|
| Debian netinst | `13.4.0` (in `download-base-iso.sh`) | SHA256 vs `SHA256SUMS` |
| Docker apt | `download.docker.com` | Docker Inc. signed key |
| Tailscale apt | `pkgs.tailscale.com` | Tailscale signed key |
| Caddy apt | `dl.cloudsmith.io/public/caddy/stable` | Cloudsmith signed key |
| NodeSource apt | `deb.nodesource.com/node_24.x` | NodeSource signed key |
| Node version | `node_major: "24"` | enforced by `apt install nodejs` |
| GitHub tools | commit SHA per repo (`bootstrap/vars/main.yml`) | git over HTTPS |
| AI CLIs (npm) | `latest` at install time | npm registry |
| AI CLIs (curl) | upstream installer URL | TLS only |

`make pin-tools` rewrites GitHub tool SHAs from upstream `HEAD`. Run before
tagging a release.

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
