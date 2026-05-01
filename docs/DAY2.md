# Day-2 Operations — `homeos` CLI

`/usr/local/bin/homeos` is a single bash script. No state of its own — every
operation edits a file Ansible manages or invokes a service.

## Top-level

```
homeos status                     # services, disks, containers, GPU, tailscale
homeos doctor                     # full smoke test (non-zero exit on any failure)
homeos secure                     # lock admin password + disable SSH password auth
homeos config <subcommand> ...    # day-2 reconfig
```

## `homeos status`

Prints a summary block:

- Hostname, uptime, kernel.
- Disk usage for `/`, `/boot`, `/srv/nas/*`.
- LVM cache hit ratio (`lvs -o +cache_read_hits,cache_write_hits`).
- `systemctl is-active` for: `docker`, `caddy`, `cockpit.socket`, `casaos`,
  `tailscaled`, `nfs-kernel-server`, `smbd`.
- `docker ps` summary.
- `tailscale status --self` (or "not connected").
- `vainfo` first line (GPU driver).

## `homeos doctor`

Runs every check from `homeos status` plus active probes:

- HTTP 200 from `localhost:8123` (HA), `localhost:8096` (Jellyfin),
  `localhost:81` (CasaOS), `localhost:9090` (Cockpit).
- Each AI CLI's `--version` invocation.
- `node -v` matches `^v24\.`.
- `docker compose version`.
- `restic version`.
- All 10 `/opt/tools/` repos cloned and built.
- `ufw status verbose` shows expected rules.
- Exits non-zero on any failure.

Run it after every config change.

## `homeos secure`

Two-phase security: at install time, password auth is on so you can upload
your first key. After that, run `secure` to lock down.

```
sudo homeos secure
```

Steps:
1. Refuses to run if `~/.ssh/authorized_keys` empty or no recognizable key.
2. Sets `PasswordAuthentication no` in `/etc/ssh/sshd_config.d/99-homeos.conf`.
3. Validates with `sshd -t` before restart.
4. `systemctl restart ssh`.
5. `passwd -l admin` (locks password).

Recovery if locked out: boot from USB, mount root, edit
`/etc/ssh/sshd_config.d/99-homeos.conf`, run `passwd -u admin`.

## `homeos config rerun-bootstrap`

```
sudo homeos config rerun-bootstrap
```

Re-runs the full Ansible playbook against localhost. Idempotent — every role
uses `state: present` semantics. Safe anytime.

Logs append to `/var/log/homeos-bootstrap.log`.

## `homeos config secrets`

Stores secrets in `~admin/.config/homeos/secrets.env` (mode 600). Sourced by
`~admin/.zshrc` on every interactive shell.

```
homeos config secrets set ANTHROPIC_API_KEY=sk-ant-...
homeos config secrets set OPENAI_API_KEY=sk-...
homeos config secrets get ANTHROPIC_API_KEY
homeos config secrets list                   # keys only, no values
homeos config secrets unset OPENAI_API_KEY
```

Reconnect SSH (or `source ~/.zshrc`) to pick up new values.

Common keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`,
`GEMINI_API_KEY`, `CURSOR_API_KEY`, `KIMI_API_KEY`, `GH_TOKEN`.

## `homeos config nas`

USB drive lifecycle. See [NAS.md](NAS.md) for full workflow.

```
homeos config nas list                       # current shares
homeos config nas add /dev/sdc1              # mount + share
homeos config nas remove <label>             # unmount + revoke share
```

`add` reads UUID + label via `blkid`, appends to `vars/nas_disks.yml`,
re-runs the `nas` role.

## `homeos config stack`

Docker Compose lifecycle.

```
homeos config stack list                     # enabled stacks + state
homeos config stack up <name>                # docker compose up -d
homeos config stack down <name>              # docker compose down
homeos config stack restart <name>
homeos config stack logs <name>              # follow logs
homeos config stack update <name>            # pull + up -d
homeos config stack ps <name>
```

Stacks live in `/opt/stacks/<name>/docker-compose.yml`.

## `homeos config net`

Tailscale + Caddy.

```
sudo homeos config net tailscale-up                          # interactive auth
sudo homeos config net tailscale-up --auth-key tskey-auth-... # one-shot
sudo homeos config net tailscale-down
sudo homeos config net caddy-reload                          # regen Caddyfile
sudo homeos config net caddy-test                            # caddy validate
```

`caddy-reload` reads current Tailscale magic DNS hostname and rewrites
`/etc/caddy/Caddyfile` accordingly.

## `homeos config backup`

Restic to a local NAS drive.

```
sudo homeos config backup target set /srv/nas/<label>        # init repo
homeos config backup target show
sudo homeos config backup run                                # one-off backup now
homeos config backup snapshots                               # restic snapshots
homeos config backup forget                                  # apply retention
homeos config backup restore <snapshot> <path>
```

Cron runs daily at 02:30 BRT after target is set.

## `homeos config portal`

Toggle the web portal (Homepage + Open WebUI + Dockge + Filebrowser + ttyd
terminals). Disabled by default; opt in to expose Tailnet-only web UIs.

```
sudo homeos config portal on        # touch flag, docker compose up
sudo homeos config portal off       # docker compose down, rm flag
homeos config portal status         # flag state + container list
```

Subdomains (Tailnet only):
- `portal.<tailnet>.ts.net` — Homepage dashboard + `/term/<tool>/`
- `chat.<tailnet>.ts.net` — Open WebUI
- `stacks.<tailnet>.ts.net` — Dockge
- `files.<tailnet>.ts.net` — Filebrowser

See [PORTAL.md](PORTAL.md) for architecture + customization.

## `homeos config cosmos`

Toggle Cosmos Cloud — alt portal w/ built-in auth, container UI, app store.
Independent of `portal`, both can run side-by-side.

```
sudo homeos config cosmos on        # bring up at cosmos.<tailnet>.ts.net
sudo homeos config cosmos off
homeos config cosmos status
```

First visit triggers setup wizard. Create admin account immediately.

## Re-runnable semantics

Every command is safe to run twice:

| Command | Twice = |
|---|---|
| `homeos config nas add /dev/sdc1` | no-op (drive already in `nas_disks.yml`) |
| `homeos config stack up jellyfin` | no-op (already running) |
| `homeos config secrets set K=V` | overwrites existing value |
| `homeos config rerun-bootstrap` | full idempotent reapply |
| `homeos secure` | no-op (password already locked) |
