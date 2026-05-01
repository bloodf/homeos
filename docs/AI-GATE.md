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

| Command | Gated? |
|---|---|
| `homeos config rerun-bootstrap` | yes |
| `homeos config portal on/off` | on |
| `homeos install <anything>` | yes |
| `homeos config nas add/remove` | TODO v0.4 |
| `homeos config secrets set` | TODO v0.4 |
| `homeos config stack up/down/update` | TODO v0.4 |
| `homeos status / doctor / audit` | no (read-only) |

Bypass: `HOMEOS_NO_REVIEW=1 homeos ...` (logged as bypass).
Auto-apply: `HOMEOS_AUTO_APPLY=1 homeos ...` (skip y/N prompt; useful in
shell scripts and ralph-style loops).

## Audit log

```bash
homeos audit tail            # last 20 entries
homeos audit tail -n 100
homeos audit search portal
```

Format (JSONL, one entry per command):

```json
{"ts":"2026-05-01T16:00:00-0300","cmd":"portal:on","user":"admin","verdict":"APPROVE","choice":"apply","diff_hash":"a1b2c3d4e5f6"}
```

Rotated weekly via `logrotate`, kept 10 years (520 weeks). Owner takes
full responsibility — see `homeos audit` to introspect.

## What the AI sees

- Intent label (e.g. `portal:on`, `rerun-bootstrap`)
- Diff text (proposed change summary)
- No secrets — `secrets.env` is never sent to the cloud provider unless
  user explicitly chose `claude`/`openai`/`openrouter` and the *prompt*
  references it (we never include keys in the prompt body)
- For Ollama provider, payload never leaves the box

## Disabling temporarily

```bash
HOMEOS_NO_REVIEW=1 sudo homeos config rerun-bootstrap
# audit log records "bypass"
```

## Roadmap

- v0.3.0 — gate on rerun-bootstrap, portal, install
- v0.4.0 — gate on nas, secrets, stack
- v0.5.0 — gate on Cosmos via Docker socket shim
- v0.6.0 — `homeos audit replay <id>` to re-run a past intent
