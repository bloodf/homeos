# Security model

HomeOS is a convenience installer for private home servers. It chooses safer defaults, but operators are responsible for network exposure, secrets, and updates.

## Security defaults

- SSH root login is disabled.
- SSH password auth is disabled when admin SSH keys exist.
- Firewall defaults deny inbound except HomeOS service ports.
- Grafana binds to `127.0.0.1` by default.
- Grafana password is generated when not provided.
- Unattended admin password is generated when needed.
- Config expansion never evaluates command substitution.
- AI project integrations isolate per-tool MCP/plugin state.

## Secrets

Sensitive files:

| File | Contains | Recommended mode |
| --- | --- | --- |
| `/etc/homeos/homeos.conf` | API keys/tokens if configured | `0600`, root-owned |
| `/var/lib/homeos/admin-password.txt` | Generated admin password | root-readable only |
| `/var/lib/homeos/grafana-password.txt` | Generated Grafana password | root-readable only |

Do not commit real config files containing secrets.

## Network exposure

Before exposing services beyond LAN/Tailscale:

1. Set strong service passwords/tokens.
2. Prefer Tailscale or VPN access.
3. Review firewall ports.
4. Review Caddy routes.
5. Confirm Grafana bind address.
6. Confirm Vaultwarden admin token is strong.

Grafana:

```bash
GRAFANA_BIND_ADDRESS="127.0.0.1" # default, safest
GRAFANA_BIND_ADDRESS="0.0.0.0"   # LAN/public exposure; review firewall first
```

## Local DNS

`INSTALL_LOCAL_DOMAINS=yes` runs dnsmasq for wildcard local domains. This is intended for LAN/private DNS. Do not use a public domain root unless you understand split-horizon DNS and certificate behavior.

Default root:

```text
homeos.home.arpa
```

## MCP and AI tool isolation

HomeOS documents local MCP inventory but does not rewrite MCP server config files.

Rules:

- Claude Code config is not copied into OpenCode.
- OpenCode config is not copied into Claude Code.
- MCP servers are not merged across tools.
- Plugin directories remain per-tool.
- Shared skills/agents are symlinked separately from MCP/plugin directories.

This keeps MCP behavior unchanged and avoids accidental credential/config leakage between tools.

## Third-party installers

Some components call upstream installers, for example Coolify or AI CLIs. HomeOS treats some third-party installer failures as non-fatal so a partially unsupported distro does not break the whole install.

Operators should review upstream installer trust before enabling components on sensitive systems.

## Config parser security

HomeOS config loading accepts known keys only and performs strict value expansion:

- exact `$VAR`
- exact `${VAR}`

It does not evaluate:

- `$(command)`
- backticks
- arithmetic expansion
- compound shell expressions

Smoke tests verify command-substitution injection does not execute.

## Reporting security issues

Until a dedicated security policy exists, open a private issue/contact the maintainer directly if possible. Do not publish exploit details in a public issue before maintainers can respond.
