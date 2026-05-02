# Bootstrap — Ansible Roles Reference

Stage B is `bootstrap/install.yml`, a single-play, single-host playbook applied
to `localhost` with `connection: local`. Roles run in this order:

```
base → ssh → shell → docker → node → brew → gpu-intel → ai-clis →
github-tools → hermes-agent → tailscale → cockpit → casaos → caddy →
stacks → portal → cosmos → nas → backups → homeos-cli → firstboot
```

Re-run anytime with `homeos config rerun-bootstrap` (idempotent).

---

## 1. `base`

System baseline. Runs first because every later role depends on its work.

- `apt update && full-upgrade -y`.
- Installs core packages: `vim tmux htop btop ncdu rsync unzip jq fzf
ripgrep build-essential ca-certificates gnupg lsb-release pciutils usbutils
python3-apt`.
- Configures `unattended-upgrades` (Debian Security pocket only).
- Sets up `ufw`:
  - Default deny inbound, allow outbound.
  - Allow loopback + Tailscale interface (`tailscale0` fully trusted).
  - Two pass loop — TCP from `firewall_allow_tcp` and UDP from `firewall_allow_udp`
    (`vars/main.yml`).
  - Default TCP: 22, 80, 443, 81, 445, 2049, 8123, 8096, 9090, 8222.
  - Default UDP: 137, 138 (Samba browse), 5353 (mDNS).
- Configures `fail2ban` with sshd jail.
- Enables `systemd-timesyncd` (`America/Sao_Paulo`).
- Attaches LVM cache: if `/dev/vg1/cache` exists, runs
  `lvconvert --type cache --cachepool vg1/cache vg0/root`. Skips on single-disk
  boxes.

## 2. `ssh`

Hardens sshd but keeps password auth available initially (so public-distro
users can upload their first key).

- Drops `/etc/ssh/sshd_config.d/99-homeos.conf`:
  ```
  PasswordAuthentication yes
  PermitRootLogin no
  KbdInteractiveAuthentication no
  UsePAM yes
  MaxAuthTries 4
  LoginGraceTime 30
  ```
- `sshd -t` validation handler before restart.
- `homeos secure` later flips `PasswordAuthentication` to `no`.

## 3. `shell`

Sets up the `admin` user's interactive shell.

- `chsh -s /usr/bin/zsh admin`.
- Installs `oh-my-zsh` (unattended, pinned commit).
- Installs `starship` via official `sh` install script.
- Drops `~admin/.zshrc`, `~admin/.config/starship.toml`, `~admin/.config/homeos/`.
- Plugins: `git docker docker-compose fzf zsh-autosuggestions zsh-syntax-highlighting`.
- Sources `~/.config/homeos/secrets.env` if present.

## 4. `docker`

Docker CE from `download.docker.com`.

- Adds Docker apt key + repo.
- Installs `docker-ce docker-ce-cli containerd.io docker-buildx-plugin
docker-compose-plugin`.
- Adds `admin` to `docker` group.
- `/etc/docker/daemon.json`: `json-file` log driver, `max-size: 10m`,
  `max-file: 3`, `live-restore: true`.
- Enables and starts `docker.service`.

## 5. `node`

Node 24 LTS via NodeSource.

- Adds NodeSource signed apt key + repo for `node_24.x`.
- Installs `nodejs`.
- Verifies `node -v` matches `^v24\.`.
- Runs `corepack enable`.
- Installs `pnpm@latest` globally.
- Installs `bun` via `curl -fsSL https://bun.sh/install | bash` as the `admin`
  user.

## 6. `brew`

Homebrew (Linuxbrew) for the `admin` user.

- Runs the official install script as `admin` (non-interactive).
- Installs to `/home/linuxbrew/.linuxbrew`.
- Appends `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` to
  `~admin/.zshrc`.
- Installs initial formulas: `gh lazygit lazydocker neovim eza bat delta dust
procs tokei`.

## 7. `gpu-intel`

Intel iGPU stack (Gen 9+ for QSV).

- Adds Debian `non-free` apt component.
- Installs `intel-media-va-driver-non-free i965-va-driver vainfo
intel-gpu-tools`.
- Adds `admin` to `render` and `video` groups.
- Verifies with `vainfo`; logs warning (does not fail) if iHD driver missing —
  AMD/no-GPU boxes still complete bootstrap.

## 8. `ai-clis`

Six CLIs.

| CLI          | Method                                         |
| ------------ | ---------------------------------------------- |
| Claude Code  | `npm i -g @anthropic-ai/claude-code`           |
| Codex        | `npm i -g @openai/codex`                       |
| Gemini       | `npm i -g @google/gemini-cli`                  |
| Cursor Agent | `curl https://cursor.com/install -fsS \| bash` |
| OpenCode     | `npm i -g opencode-ai`                         |
| Kimi         | `curl -fsSL <upstream> \| sh`                  |

Each runs `command -v <cli>` afterwards and logs version.

## 9. `github-tools`

Clones 10 repos under `/opt/tools/`, owned by `admin`. Pinned commit SHAs in
`vars/main.yml` (refresh via `make pin-tools`).

| Repo                         | Build                                              |
| ---------------------------- | -------------------------------------------------- |
| vectorize-io/hindsight       | npm                                                |
| tirth8205/code-review-graph  | pipx                                               |
| vercel-labs/portless         | pnpm                                               |
| zilliztech/claude-context    | npm + Milvus stack                                 |
| utooland/utoo                | cargo                                              |
| NousResearch/hermes-agent    | pipx                                               |
| volcengine/OpenViking        | docker compose                                     |
| opensoft/oh-my-opencode      | symlink → `~admin/.config/opencode/plugins/`       |
| yeachan-heo/oh-my-claudecode | symlink → `~admin/.claude/`                        |
| thedotmack/claude-mem        | install hooks into Claude Code, Codex, Cursor only |

## 10. `tailscale`

- Adds `pkgs.tailscale.com` apt repo.
- Installs `tailscale tailscale-archive-keyring`.
- Enables `tailscaled.service`.
- **Does not** run `tailscale up` — the user runs `homeos config net
tailscale-up` after first SSH.

## 11. `cockpit`

Headless web dashboard for systemd, storage, and NAS file sharing.

- Installs `cockpit cockpit-storaged cockpit-networkmanager cockpit-podman`.
- Adds 45Drives apt key + repo, installs `cockpit-file-sharing
cockpit-navigator cockpit-identities`.
- Enables `cockpit.socket`.
- Listens on `:9090` (LAN + Tailscale).

## 12. `casaos`

App dashboard.

- Pinned `casaos_version` from `vars/main.yml`.
- Runs the official `get.casaos.io` installer with version env.
- Disables CasaOS's built-in file-sharing app to prevent overlap with Cockpit.

## 13. `caddy`

Reverse proxy with Tailscale-issued certs.

- Adds Cloudsmith Caddy stable apt repo.
- Installs `caddy`.
- Drops `/etc/caddy/Caddyfile` from `Caddyfile.j2` template — defines per-service
  hosts on `*.<tailnet>.ts.net` magic DNS.
- Uses `tls { get_certificate tailscale }` directive (no LetsEncrypt).
- Enables `caddy.service` (idle until `tailscale up` succeeds).

## 14. `stacks`

Docker Compose stacks under `/opt/stacks/<name>/`.

- Renders `docker-compose.yml.j2` per stack from `vars/stacks.yml`.
- Creates `/srv/<service>/` data directories.
- Runs `docker compose up -d` for each enabled stack.

Stacks: `homeassistant`, `jellyfin`, `vaultwarden`, `watchtower`,
`milvus-standalone` (only if `claude-context` enabled).

Watchtower opt-in via `com.centurylinklabs.watchtower.enable=true` label.
HA + Vaultwarden are explicitly excluded.

## 15. `cosmos`

Alternative portal with Docker UI. Disabled by default until `homeos config cosmos on`.

- Renders `/opt/stacks/cosmos/docker-compose.yml`.
- Installs `/usr/local/sbin/homeos-cosmos-docker-shim`.
- Installs and manages `homeos-cosmos-docker-shim.service`, which listens on
  `/var/run/cosmos-docker.sock`, forwards to `/var/run/docker.sock`, and writes
  `BYPASS` audit entries for mutating Docker API methods.
- Installs `homeos-cosmos.service`, a systemd-managed compose launcher ordered
  after the Docker socket shim so boot and `homeos config cosmos on` do not bind
  Cosmos to a missing shim path.
- Mounts the shim socket into Cosmos as `/var/run/docker.sock`; the real Docker
  socket is not mounted directly.
- Disables the legacy v0.4 `homeos-cosmos-audit.service` log tailer.

## 16. `nas`

USB drive mount + Samba/NFS export.

- Installs `samba nfs-kernel-server`.
- Generates `/etc/udev/rules.d/99-homeos-nas.rules` from `nas_disks.yml`
  (creates `/dev/disk/by-homeos/<label>` symlinks).
- Generates `/etc/systemd/system/srv-nas-<label>.mount` units with
  `nofail,noauto,x-systemd.automount,x-systemd.device-timeout=10s` — missing
  drive never blocks boot.
- Generates `/etc/samba/smb.conf` from template (SMB3 minimum, guest disabled).
- Generates `/etc/exports` from template (LAN-scoped NFS).
- `nas_disks.yml` starts empty — populated at runtime via
  `homeos config nas add /dev/sdcN`.

## 17. `backups`

Restic + cron.

- Installs `restic rclone`.
- Drops helper script `/usr/local/lib/homeos/backup-run.sh`.
- Cron at 02:30 BRT: `restic backup /srv /opt/stacks /home/admin --exclude-caches`.
- Weekly forget+prune: `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`.
- Refuses to run if backup target unmounted.
- Target configured at runtime via `homeos config backup target set /srv/nas/<backup-label>`.

## 18. `homeos-cli`

Day-2 CLI.

- Installs `/usr/local/bin/homeos` (single bash script).
- Bash + zsh completions to `/etc/bash_completion.d/` and
  `/usr/share/zsh/vendor-completions/`.
- Creates `/var/lib/homeos/` for state files.

## 19. `firstboot`

Self-disabling service.

- Installs `/etc/systemd/system/homeos-firstboot.service`:

  ```
  [Unit]
  After=network-online.target
  Wants=network-online.target
  RequiresMountsFor=/opt/homeos
  ConditionPathExists=!/var/lib/homeos/bootstrapped

  [Service]
  Type=oneshot
  ExecStartPre=/bin/sh -c 'mkdir -p /var/lib/homeos; echo "==== homeos-firstboot service start $(date -Is) ===="'
  ExecStartPre=/usr/bin/ansible-galaxy collection install -r /opt/homeos/bootstrap/requirements.yml
  ExecStart=/usr/bin/ansible-playbook -i localhost, -c local /opt/homeos/bootstrap/install.yml
  ExecStartPost=/bin/sh -c 'echo "==== homeos-firstboot service success $(date -Is) ===="; systemctl disable homeos-firstboot.service'
  StandardOutput=append:/var/log/homeos-bootstrap.log
  StandardError=append:/var/log/homeos-bootstrap.log
  ```

- The playbook touches `/var/lib/homeos/bootstrapped` only in `post_tasks`,
  after all roles and the success log task finish.
- On success: the service logs completion and disables itself.
- On failure: the marker is absent, the service stays enabled, and it retries
  on next boot. SSH already works so the operator can debug.

## CasaOS installer trust policy

CasaOS remains version-pinned with `casaos_version`, but the upstream installer script is governed separately:

- `casaos_installer_url` defaults to `https://get.casaos.io`.
- `casaos_installer_sha256` can pin the installer script by SHA-256.
- `casaos_allow_unverified_installer` defaults to `false`, so installs fail closed unless a checksum is configured.

Set `casaos_allow_unverified_installer: true` only when you explicitly accept the TLS-only upstream installer risk without a checksum.
