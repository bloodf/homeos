# Portal — Web UI for non-tech users

Toggle-aware dashboard at `https://portal.<tailnet>.ts.net` bundling the best
self-hosted UIs for managing HomeOS without SSH:

| Component  | What it does                                  | Subdomain                    |
|------------|-----------------------------------------------|------------------------------|
| Homepage   | Landing dashboard with widgets + service grid | `portal.<tailnet>.ts.net`    |
| Open WebUI | Chat with Claude, GPT, Gemini APIs            | `chat.<tailnet>.ts.net`      |
| Dockge     | Manage docker-compose stacks under /opt/stacks| `stacks.<tailnet>.ts.net`    |
| Filebrowser| Web file manager for /srv (NAS, configs)      | `files.<tailnet>.ts.net`     |
| ttyd × 8   | Per-tool web terminals (Claude, Codex, …)     | `portal/term/<name>/`        |

All bound to `127.0.0.1`; Caddy is the only external entrypoint and Tailscale
identity is the auth boundary.

## Toggle from SSH

Portal is **disabled by default** — files install but nothing runs. Opt in:

```bash
sudo homeos config portal on       # touch flag, docker compose up
sudo homeos config portal off      # docker compose down, rm flag
homeos config portal status        # show flag + container state
```

The flag lives at `/var/lib/homeos/portal.enabled`. On every
`homeos config rerun-bootstrap` the portal role honors the flag — present
means up, absent means down.

## ttyd terminals

| Card | Endpoint | Backed by |
|---|---|---|
| Claude Code | `/term/claude/` | `claude` (7681) |
| Codex | `/term/codex/` | `codex` (7682) |
| Gemini | `/term/gemini/` | `gemini` (7683) |
| Cursor Agent | `/term/cursor/` | `cursor-agent` (7684) |
| OpenCode | `/term/opencode/` | `opencode` (7685) |
| Kimi | `/term/kimi/` | `kimi` (7686) |
| Hermes Agent | `/term/hermes/` | `/usr/local/bin/hermes` (7687) |
| Shell | `/term/shell/` | `bash -i` as admin (7688) |

ttyd containers bind only to `127.0.0.1:7681-7688` and are reachable
through Caddy `/term/<name>/` routes. They do not use host networking. Secrets
are bind-mounted read-only at `/secrets.env`; launcher sources them before
exec'ing the CLI.

## Architecture

```
Browser (Tailscale)
   ↓ HTTPS (Tailscale cert)
Caddy :443
   ├── portal.<tailnet>  → Homepage :3001
   │     └── /term/<x>/* → ttyd-<x> :768N
   ├── chat.<tailnet>    → Open WebUI :3002
   ├── stacks.<tailnet>  → Dockge :5001
   └── files.<tailnet>   → Filebrowser :8090
```

## Stack location

```
/opt/stacks/portal/docker-compose.yml   # stack
/srv/portal/homepage/                   # Homepage YAML configs
/srv/portal/open-webui/                 # Open WebUI data
/srv/portal/dockge/                     # Dockge state
/srv/portal/filebrowser/                # Filebrowser db + settings
/srv/portal/launch.sh                   # ttyd entrypoint
```

## Security

- **Tailnet only.** No LAN exposure. Tailscale ACLs are the auth boundary.
- **Disabled by default.** Operator opts in explicitly.
- **Containers run as admin.** Same blast radius as SSH-as-admin.
- **Secrets read-only.** `secrets.env` mounted `:ro`.
- Open WebUI signups disabled — first user becomes admin via
  `WEBUI_AUTH_TRUSTED_EMAIL_HEADER` or manual creation.

To layer basicauth on a subdomain, edit
`bootstrap/roles/caddy/templates/Caddyfile.j2`:

```caddyfile
handle @chat {
    basicauth { admin <bcrypt-hash> }
    reverse_proxy localhost:3002
}
```

Generate hash with `caddy hash-password`.

## Customizing

### Add a Homepage card

Edit `bootstrap/roles/portal/templates/homepage-services.yaml.j2`,
re-run bootstrap. No restart needed — Homepage hot-reloads YAML.

### Add a ttyd tool

1. Append service to `portal-compose.yml.j2` (use `*ttyd-common` anchor).
2. Add `case` arm in `launch.sh.j2`.
3. Add `handle_path /term/newtool/*` to the `@portal` block in
   `bootstrap/roles/caddy/templates/Caddyfile.j2`.
4. Add card to `homepage-services.yaml.j2`.
5. `sudo homeos config rerun-bootstrap`.

## Troubleshooting

### `homeos config portal on` says stack not installed

The portal role hasn't deployed compose files yet:

```bash
sudo homeos config rerun-bootstrap
sudo homeos config portal on
```

### Card → 502

ttyd container down. Check:

```bash
docker ps --filter "label=com.docker.compose.project=portal"
homeos config stack logs portal
```

### "command not found" inside terminal

CLI not installed for `admin`. From SSH:

```bash
which claude codex gemini cursor-agent opencode kimi hermes
sudo homeos config rerun-bootstrap   # if missing
```

### CLI complains about missing API key

```bash
homeos config secrets list
sudo homeos config secrets set ANTHROPIC_API_KEY=<anthropic-key>
sudo homeos config portal off && sudo homeos config portal on
```

## Alternative: Cosmos Cloud

Cosmos = single-package replacement bundling auth + reverse proxy + container
UI + app store. Independent of the Homepage stack — toggle separately.

```bash
sudo homeos config cosmos on        # bring up at cosmos.<tailnet>.ts.net
sudo homeos config cosmos off
homeos config cosmos status
```

Runs `azukaar/cosmos-server:latest` bound to `127.0.0.1:4444`, fronted by
Caddy at `cosmos.<tailnet>.ts.net`. First visit triggers setup wizard —
create admin account immediately (Tailscale ACL is your only protection
until then).

Trade-offs vs default Homepage stack:
- ✅ Built-in auth (2FA, OIDC, magic links)
- ✅ App store with one-click installs
- ✅ Native Docker UI
- ❌ Wants to be the reverse proxy itself (here we run it behind Caddy)
- ❌ More opinionated, less Tailscale-native
- ❌ Heavier resource footprint

Both stacks can run simultaneously. Pick one as primary.

### Wrong tailnet hostname

`tailnet_host` baked at bootstrap. Reapply after `tailscale up`:

```bash
sudo HOMEOS_TAILNET=$(tailscale status --json | jq -r .Self.DNSName | sed 's/\.$//') \
  homeos config rerun-bootstrap
```
