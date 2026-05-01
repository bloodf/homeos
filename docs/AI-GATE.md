# AI Review Gate

HomeOS routes every mutating CLI command through an optional AI reviewer.
Warn-only — owner has final say. Designed for "AI-enforced process"
without becoming a roadblock.

## Flow

```
homeos <mutating cmd>
   ↓
render diff (intent + change summary)
   ↓
AI review (if provider set)  →  APPROVE | WARN: <reason> | REJECT: <reason>
   ↓
human confirm (y/N) — even REJECT can be applied
   ↓
apply
   ↓
audit log → /var/log/homeos-audit.jsonl (append-only, retained forever)
```

## Pick a provider

```bash
sudo homeos config gate set claude       # uses ANTHROPIC_API_KEY
sudo homeos config gate set openai       # uses OPENAI_API_KEY (Codex CLI)
sudo homeos config gate set openrouter   # uses OPENROUTER_API_KEY (via OpenCode)
sudo homeos config gate set ollama       # local qwen3:7b — install via `homeos install ollama`
sudo homeos config gate set none         # disable (still audit-logged)

homeos config gate show
```

Provider stored in `/var/lib/homeos/ai-gate-provider`. Keys come from
`~admin/.config/homeos/secrets.env` — set via `homeos install ai-keys`.

## What's gated

| Command                              | Gated?                           |
| ------------------------------------ | -------------------------------- |
| `homeos config rerun-bootstrap`      | yes                              |
| `homeos config portal on/off`        | yes                              |
| `homeos install <anything>`          | yes                              |
| `homeos config nas add/remove`       | yes                              |
| `homeos config secrets set`          | yes (value redacted from diff)   |
| `homeos config stack up/down/update` | yes                              |
| `homeos config cosmos on/off`        | yes                              |
| `homeos status / doctor / audit`     | no (read-only)                   |
| Cosmos UI Docker actions             | Docker socket shim; BYPASS audit |

Bypass: `HOMEOS_NO_REVIEW=1 homeos ...` (logged as bypass).
Auto-apply: `HOMEOS_AUTO_APPLY=1 homeos ...` (skip y/N prompt; useful in
shell scripts and ralph-style loops).

## Audit log

```bash
homeos audit tail            # last 20 entries
homeos audit tail -n 100
homeos audit search portal
homeos audit cosmos-events   # Cosmos-origin bypass events only
```

Format (JSONL, one entry per command):

```json
{
  "ts": "2026-05-01T16:00:00-0300",
  "cmd": "portal:on",
  "user": "admin",
  "verdict": "APPROVE",
  "choice": "apply",
  "diff_hash": "a1b2c3d4e5f6"
}
```

Rotated weekly via `logrotate`, kept 10 years (520 weeks). Owner takes
full responsibility — see `homeos audit` to introspect.

## Cosmos Docker socket shim

Cosmos has its own web UI and talks to Docker directly. In v0.5.x HomeOS mounts
`/var/run/cosmos-docker.sock` into the Cosmos container as `/var/run/docker.sock`.
`homeos-cosmos-docker-shim.service` listens on that socket, forwards requests to
the real `/var/run/docker.sock`, and writes an audit entry for mutating Docker
API methods (`POST`, `PUT`, `DELETE`) against Docker containers, images,
networks, and volumes. The shim is informational: it records `BYPASS` and does
not block Cosmos UI actions.

Shim entries use:

- `cmd`: `cosmos:<verb>:<resource>` (for example `cosmos:post:containers`)
- `user`: `cosmos`
- `verdict`: `BYPASS`
- `choice`: `observed`
- `source`: `cosmos-docker-shim`
- `summary`: `<METHOD> <path>` plus body hash/size/truncation metadata

Request bodies are never written to the public audit log; only SHA-256 hash,
size, and truncation metadata are kept for correlation. Read-only methods such as
`GET /containers/json` are proxied without audit entries. The Cosmos compose
stack is launched through `homeos-cosmos.service`, ordered after
`homeos-cosmos-docker-shim.service`, so
normal boot and CLI toggles start the shim before the container bind-mounts it.

Inspect Cosmos-origin events with:

```bash
homeos audit cosmos-events
homeos audit cosmos-events -n 100
```

Acceptance target: a container stopped from the Cosmos UI should appear in the
HomeOS audit log within 5 seconds while the shim service is running.

## What the AI sees

- Intent label (e.g. `portal:on`, `rerun-bootstrap`)
- Diff text (proposed change summary)
- No secrets — `secrets.env` is never sent to the cloud provider unless
  user explicitly chose `claude`/`openai`/`openrouter` and the _prompt_
  references it (we never include keys in the prompt body)
- For Ollama provider, payload never leaves the box

## Disabling temporarily

```bash
HOMEOS_NO_REVIEW=1 sudo homeos config rerun-bootstrap
# audit log records "bypass"
```

## Roadmap

- v0.3.0 — gate on rerun-bootstrap, portal, install
- v0.4.0 — gate on nas, secrets, stack, plus Cosmos bypass-warn audit mirror
- v0.5.0 — Cosmos Docker socket shim emits BYPASS audit entries
- v0.6.0 — `homeos audit replay <id>` to re-run a past intent
