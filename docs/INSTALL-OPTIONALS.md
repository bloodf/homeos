# Optional Installers — `homeos install`

Opt-in features. Nothing here runs by default. Flag-tracked at
`/var/lib/homeos/installed.d/<feat>.installed`.

```bash
homeos install --list
sudo homeos install <feature>             # first run: prompts you
sudo homeos install <feature> --reconfigure  # re-prompt
```

Every installer is gated by the AI review (see [AI-GATE.md](AI-GATE.md))
and audit-logged.

## Available

| Feature          | What it adds                                                                                        |
| ---------------- | --------------------------------------------------------------------------------------------------- |
| `ai-keys`        | Wizard for ANTHROPIC / OPENAI / GOOGLE / CURSOR / OPENROUTER / MOONSHOT / GROQ keys → `secrets.env` |
| `ollama`         | Local LLM (Ollama + qwen3:7b default). Asks GPU type. Refuses naive CPU-only                        |
| `mcp-hub`        | Installs official MCP servers + writes `mcp.json` for claude/codex/cursor/opencode                  |
| `monitoring`     | Uptime Kuma + Scrutiny (disk SMART) + weekly Trivy scan                                             |
| `media-stack`    | Sonarr / Radarr / Prowlarr / Bazarr / qBittorrent — Jellyfin pipeline                               |
| `offsite-backup` | Restic to B2 / Storj / Hetzner SB / S3 / rclone — daily 03:30 BRT                                   |
| `image-gen`      | ComfyUI (NVIDIA-only, refuses without GPU)                                                          |
| `voice`          | Whisper + Piper (Wyoming) → HA voice assist                                                         |

## Security and provenance notes

Optional installers are admin-triggered, AI-gated, and audit-logged. They are
not part of the unattended base install.

| Feature          | Sensitive access / supply-chain note                                                                                                     | Accepted risk                                                                       |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `ai-keys`        | Writes API keys to `~admin/.config/homeos/secrets.env` mode 600; prompts hide input and do not echo prefixes.                            | Keys are sourced into admin shells and selected portal containers.                  |
| `ollama`         | Downloads upstream Ollama installer over TLS when `ollama` is absent; compose uses `ollama/ollama:latest`.                               | Moving model/runtime channel; local-only port bind.                                 |
| `mcp-hub`        | Installs npm MCP servers and `mcp-server-docker`; generated config grants filesystem access to `/srv`, `/opt/stacks`, and `/opt/homeos`. | MCP servers run with the invoking user's trust boundary.                            |
| `monitoring`     | Scrutiny runs privileged with raw disk/device access; Trivy apt repo uses a scoped signed keyring.                                       | Disk-health visibility requires broad host access.                                  |
| `media-stack`    | LinuxServer.io `latest` images for the arr/qBittorrent suite; media/downloads bind mounts.                                               | Moving app tags and downloader exposure; local/Tailnet Caddy routes only.           |
| `offsite-backup` | Writes provider credentials to `/etc/homeos/backup.env` mode 600.                                                                        | Offsite provider sees encrypted restic blobs and metadata; protect restic password. |
| `image-gen`      | NVIDIA-only ComfyUI image with GPU device reservation and `/srv/comfyui` bind mount.                                                     | Large moving container image; refuses CPU-only mode.                                |
| `voice`          | Wyoming Whisper/Piper `latest` images with local-only ports.                                                                             | Moving speech service images; no direct public exposure.                            |

## Ordering recommendation

1. `ai-keys` — needed before `gate` is useful w/ cloud providers
2. `ollama` — gives you a local AI for the gate (no API spend)
3. `mcp-hub` — multiplies CLI capability
4. `monitoring` — visibility before you add more stacks
5. Everything else as needed

## Custom installers

Drop `*.sh` into `/opt/homeos/bootstrap/installers/`. Add the name to
the `INSTALLERS` array in `/usr/local/bin/homeos`. Re-run
`homeos install --list` to verify.

Installers receive `--reconfigure` flag when re-run with that argument;
script decides what that means.
