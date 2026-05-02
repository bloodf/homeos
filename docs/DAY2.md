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
  `tailscaled`, `nfs-kernel-server`, `smbd`, and the Cosmos Docker shim.
- `docker ps` summary.
- `homeos-cosmos-docker-shim.service` state and active-since timestamp.
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
2. Repairs `~/.ssh` and `authorized_keys` ownership/modes for `admin`.
3. Sets `PasswordAuthentication no` in `/etc/ssh/sshd_config.d/99-homeos.conf`.
4. Validates with `sshd -t` and confirms effective public-key auth plus
   `.ssh/authorized_keys` lookup with `sshd -T` before restart.
5. `systemctl restart ssh`.
6. `passwd -l admin` (locks password).

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
sudo homeos config secrets set ANTHROPIC_API_KEY=<anthropic-key>
sudo homeos config secrets set OPENAI_API_KEY=<openai-key>
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
homeos config stack list                     # installed stack names
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
sudo homeos config net caddy-reload                          # reload Caddy
sudo homeos config net caddy-test                            # caddy validate
```

`caddy-reload` reloads the current Caddy configuration. Use `caddy-test` first
when editing Caddy configuration by hand.

## `homeos config backup`

Restic to a local NAS drive.

```
sudo homeos config backup target set /srv/nas/<label>        # init repo
sudo homeos config backup target show
sudo homeos config backup run                                # one-off backup now
sudo homeos config backup snapshots                          # restic snapshots
sudo homeos config backup forget                             # apply retention
sudo homeos config backup restore <snapshot> <path>
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

Cosmos UI container mutations bypass the interactive AI gate, but v0.5 routes
Cosmos through `/var/run/cosmos-docker.sock`. The
`homeos-cosmos-docker-shim.service` proxy forwards to the real Docker socket and
audit-logs mutating container/image/network/volume Docker API methods with
`cmd=cosmos:<verb>:<resource>` and verdict `BYPASS`:

```bash
homeos audit cosmos-events
homeos audit cosmos-events -n 100
```

Read-only Docker API calls are proxied without audit entries. `homeos config
cosmos on` starts `homeos-cosmos-docker-shim.service` before
`homeos-cosmos.service` launches the compose stack; the same ordering is enabled
for boot. The legacy v0.4 log-tail audit service is disabled to avoid duplicate
events.

## `homeos audit`

Audit commands inspect the public redacted JSONL log and, for root, the
short-lived replay sidecars for mutating CLI commands.

```bash
homeos audit tail                 # last 20 public entries
homeos audit tail -n 100
homeos audit search portal
homeos audit show 42              # public line 42; root also sees sidecar JSON
homeos audit show a1b2c3d4e5f6     # by unique diff hash
sudo homeos audit replay 42       # re-run saved argv through the AI gate
homeos audit cosmos-events
```

`audit show` accepts either a line-number ID or a unique `diff_hash`. Non-root
users see the public JSONL entry and a clear root-only refusal for sidecar
content. Root sees the sidecar payload, including original argv and redaction
metadata.

`audit replay` uses the sidecar to re-execute the original `homeos` argv through
the normal gate. The follow-up audit line is recorded as
`audit:replay:<orig_cmd>`. If the sidecar was pruned or a hash is ambiguous,
replay refuses and asks for a line-number ID or reports the missing sidecar.
Public JSONL retention remains 10 years; replay sidecars are pruned after 90
days by `homeos-audit-prune.timer`.

## Re-runnable semantics

Every command is safe to run twice:

| Command                              | Twice =                                          |
| ------------------------------------ | ------------------------------------------------ |
| `homeos config nas add /dev/sdc1`    | no-op (drive already in `nas_disks.yml`)         |
| `homeos config stack up jellyfin`    | no-op (already running)                          |
| `sudo homeos config secrets set K=V` | overwrites existing value through the audit gate |
| `homeos config rerun-bootstrap`      | full idempotent reapply                          |
| `homeos secure`                      | no-op (password already locked)                  |

## Guided first run, diagnostics, and logs

After first SSH and firstboot completion, run the guided CLI flow:

```bash
sudo homeos init
```

Useful non-mutating previews:

```bash
homeos init --dry-run
homeos upgrade --check
homeos diag
homeos log firstboot --lines 200
```

`homeos init` orchestrates existing audited commands instead of writing parallel config: `secure`, Tailscale setup, secrets, NAS, and backup target setup. Use `--skip-secure`, `--skip-tailscale`, `--skip-secrets`, `--skip-nas`, or `--skip-backup` to defer steps. `--auth-key`, `--nas-device`, and `--backup-target` allow explicit non-secret inputs. Secret prompts do not echo values.

`homeos diag` is read-only triage with next-action suggestions. `homeos doctor` remains the stricter smoke test and exits non-zero when required services are unavailable.

`homeos log` supports common local targets:

```bash
homeos log summary
homeos log bootstrap --lines 200
homeos log firstboot --follow
homeos log backup --lines 100
homeos log docker
homeos log stack:jellyfin --lines 100
```

## Routine upgrades

Run a read-only preview first:

```bash
homeos upgrade --check
```

Then apply routine maintenance:

```bash
sudo homeos upgrade
```

The command runs `apt-get update && apt-get upgrade -y`, updates Linuxbrew when installed, records stack image digests, preflights free disk space, pulls Docker images, recreates stacks, and then runs `homeos doctor`. It does not run `full-upgrade`, Debian release upgrades, firmware migrations, or reboot automation. Use `--skip-apt`, `--skip-docker`, `--skip-brew`, or `--skip-doctor` to narrow scope.

## Backup verification and free-space preflight

Manual verification:

```bash
sudo homeos config backup verify
sudo homeos config backup verify --read-data-subset 5%
```

HomeOS also installs `/usr/local/sbin/homeos-backup-verify` and runs it weekly via cron. Local backup runs check free space before mutation:

- `HOMEOS_BACKUP_REPO_MIN_FREE_MIB` defaults to `10240` for local restic repositories.
- `HOMEOS_RESTIC_CACHE_MIN_FREE_MIB` defaults to `1024` for restic cache space.
- Remote repository capacity cannot be checked locally; the command prints that limitation.

## Stack digest snapshots and rollback

Before `homeos config stack update NAME` or `homeos upgrade` updates a stack, HomeOS records a pre-update image snapshot in `/var/lib/homeos/stack-digests`.

```bash
sudo homeos config stack update jellyfin
homeos config stack digests jellyfin
sudo homeos config stack rollback jellyfin
sudo homeos config stack rollback jellyfin /var/lib/homeos/stack-digests/jellyfin-YYYYMMDDTHHMMSSZ.json
```

Rollback pins compose `image:` values to recorded immutable `repo@sha256:...` digests when all services have repo digests. It intentionally fails closed for local-only or digestless images and does not roll back persistent volumes, databases, app migrations, or compose environment changes.

## Firstboot failure sentinel

If firstboot fails, systemd writes `/var/lib/homeos/bootstrap-failed`. `homeos status`, `homeos doctor`, and `homeos diag` surface the failure and point to:

```bash
sudo systemctl status homeos-firstboot.service
sudo homeos log firstboot --lines 200
sudo tail -n 200 /var/log/homeos-bootstrap.log
```
