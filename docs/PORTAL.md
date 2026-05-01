# Portal — Web UI for CLI tools

Single-page dashboard at `https://portal.<tailnet>.ts.net` exposing every CLI
tool as a browser terminal, plus links to all web UIs.

## What it does

- Dashboard (`/`) — landing page with cards for each AI CLI, agent, and
  service.
- Per-tool web terminals (`/term/<name>/`) — backed by `ttyd`, one container
  per tool. Click a card → full PTY in browser → CLI runs as `admin` with
  secrets sourced from `~/.config/homeos/secrets.env`.
- Links to existing web UIs (CasaOS, HA, Jellyfin, Cockpit, Vaultwarden).

## Tools exposed via web terminal

| Card | Endpoint | Backed by |
|---|---|---|
| Claude Code | `/term/claude/` | `claude` (port 7681) |
| Codex | `/term/codex/` | `codex` (port 7682) |
| Gemini | `/term/gemini/` | `gemini` (port 7683) |
| Cursor Agent | `/term/cursor/` | `cursor-agent` (port 7684) |
| OpenCode | `/term/opencode/` | `opencode` (port 7685) |
| Kimi | `/term/kimi/` | `kimi` (port 7686) |
| Hermes Agent | `/term/hermes/` | `/usr/local/bin/hermes` (port 7687) |
| Shell | `/term/shell/` | `bash -i` as admin (port 7688) |

## Architecture

```
Browser (Tailscale)
   ↓ HTTPS (Tailscale cert)
Caddy :443  →  portal.<tailnet>.ts.net
   ├── /            →  nginx :8080  (static dashboard + portal.css)
   └── /term/<x>/*  →  ttyd-<x> :768N  (websocket PTY)
```

All ttyd containers run with `network_mode: host` so they share PATH with
the host (Node, brew, AI CLIs installed in `admin`'s home are reachable).

Secrets bind-mounted read-only at `/secrets.env`. Launcher script sources
them before exec'ing the CLI.

## Stack location

```
/opt/stacks/portal/docker-compose.yml   # the stack
/srv/portal/www/index.html              # dashboard HTML
/srv/portal/www/portal.css              # styles
/srv/portal/launch.sh                   # ttyd entrypoint
```

## Bring up / down

```bash
homeos config stack up portal
homeos config stack down portal
homeos config stack restart portal
homeos config stack logs portal
homeos config stack update portal
```

## Security

- **Tailnet only.** Nothing in the portal is exposed to LAN. Caddy serves
  it on `portal.<tailnet>.ts.net:443` with Tailscale ACME-equivalent certs.
- **No additional auth.** Tailscale identity is the auth boundary. Use
  Tailscale ACLs to restrict who can reach `portal.*`.
- **Containers run as `admin`.** Same blast radius as SSHing in as `admin`.
  Don't share the portal with anyone you wouldn't give SSH access to.
- **Secrets read-only.** `secrets.env` is mounted `:ro`. Containers can't
  write to it.

For tighter access control, add basicauth to the Caddy `@portal` block:

```caddyfile
@portal host portal.{$HOMEOS_TAILNET}
handle @portal {
    basicauth {
        admin <bcrypt-hash>
    }
    # ... existing handlers
}
```

Generate hash with `caddy hash-password`.

## Customizing

Add a new tool card:

1. Append a service to `bootstrap/roles/portal/templates/portal-compose.yml.j2`:
   ```yaml
   ttyd-newtool:
     <<: *ttyd-common
     container_name: ttyd-newtool
     command: ["ttyd", "-W", "-p", "7689", "-t", "titleFixed=NewTool", "/launch.sh", "newtool"]
   ```
2. Append a `case` arm to `launch.sh.j2` if the binary needs special args.
3. Add a `<a class="card cli">` to `index.html.j2`.
4. Add a Caddy `handle_path /term/newtool/* { reverse_proxy localhost:7689 }`
   line to the `@portal` block in `bootstrap/roles/caddy/templates/Caddyfile.j2`.
5. `sudo homeos config rerun-bootstrap`.

## Troubleshooting

### Card click → 502

The ttyd container isn't running.

```bash
docker ps --filter "name=ttyd-"
homeos config stack logs portal
```

### Terminal connects but CLI says "command not found"

The CLI isn't installed for the `admin` user, or PATH is wrong inside the
container. Check:

```bash
ssh admin@homeos.<tailnet>.ts.net
which claude codex gemini cursor-agent opencode kimi hermes
```

If `which` fails for one, fix the install:

```bash
sudo homeos config rerun-bootstrap
```

### Terminal connects but CLI complains about missing API key

Open a `/term/shell/` session and check:

```bash
homeos config secrets list
echo "$ANTHROPIC_API_KEY" | head -c 8
```

If the value isn't set:

```bash
exit
homeos config secrets set ANTHROPIC_API_KEY=sk-ant-...
homeos config stack restart portal
```

### Wrong tailnet hostname on the dashboard

The HTML has `tailnet_host` baked in at bootstrap time. Update via:

```bash
sudo HOMEOS_TAILNET=$(tailscale status --json | jq -r .Self.DNSName | sed 's/\.$//') \
  ansible-playbook -i localhost, -c local /opt/homeos/bootstrap/install.yml --tags portal
```

Or just reapply the whole bootstrap after `tailscale up`.
