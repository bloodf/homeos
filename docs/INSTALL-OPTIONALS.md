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

| Feature | What it adds |
|---|---|
| `ai-keys`        | Wizard for ANTHROPIC / OPENAI / GOOGLE / CURSOR / OPENROUTER / MOONSHOT / GROQ keys → `secrets.env` |
| `ollama`         | Local LLM (Ollama + qwen3:7b default). Asks GPU type. Refuses naive CPU-only |
| `mcp-hub`        | Installs official MCP servers + writes `mcp.json` for claude/codex/cursor/opencode |
| `monitoring`     | Uptime Kuma + Scrutiny (disk SMART) + weekly Trivy scan |
| `media-stack`    | Sonarr / Radarr / Prowlarr / Bazarr / qBittorrent — Jellyfin pipeline |
| `offsite-backup` | Restic to B2 / Storj / Hetzner SB / S3 / rclone — daily 03:30 BRT |
| `image-gen`      | ComfyUI (NVIDIA-only, refuses without GPU) |
| `voice`          | Whisper + Piper (Wyoming) → HA voice assist |

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
