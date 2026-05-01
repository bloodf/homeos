#!/usr/bin/env bash
# MCP server hub. Installs official MCP servers + registers them in
# Claude/Codex/Cursor admin configs.
set -euo pipefail
ADMIN_USER="${SUDO_USER:-admin}"
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
NPM_PREFIX="$ADMIN_HOME/.npm-global"

echo "== MCP server hub =="

sudo -u "$ADMIN_USER" mkdir -p "$NPM_PREFIX"
sudo -u "$ADMIN_USER" -E npm config set prefix "$NPM_PREFIX" || true

# Official + community MCP servers (npm-distributed, run via npx)
SERVERS=(
  "@modelcontextprotocol/server-filesystem"
  "@modelcontextprotocol/server-git"
  "@modelcontextprotocol/server-github"
  "@modelcontextprotocol/server-fetch"
  "@modelcontextprotocol/server-sequential-thinking"
  "@modelcontextprotocol/server-everything"
)

for s in "${SERVERS[@]}"; do
  sudo -u "$ADMIN_USER" -E npm i -g "$s" 2>/dev/null || echo "  warn: failed $s"
done

# Docker MCP
sudo -u "$ADMIN_USER" -E pip install --user --break-system-packages mcp-server-docker 2>/dev/null || true

# Generate MCP config for each AI CLI that supports it
write_mcp_config() {
  local target="$1"
  install -d -o "$ADMIN_USER" -g "$ADMIN_USER" "$(dirname "$target")"
  cat >"$target" <<JSON
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/srv", "/opt/stacks", "/opt/homeos"]
    },
    "git": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-git", "--repository", "/opt/homeos"] },
    "github": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"] },
    "fetch": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-fetch"] },
    "sequential-thinking": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"] },
    "docker": { "command": "python3", "args": ["-m", "mcp_server_docker"] }
  }
}
JSON
  chown "$ADMIN_USER:$ADMIN_USER" "$target"
}

write_mcp_config "$ADMIN_HOME/.config/claude/mcp.json"
write_mcp_config "$ADMIN_HOME/.codex/mcp.json"
write_mcp_config "$ADMIN_HOME/.cursor/mcp.json"
write_mcp_config "$ADMIN_HOME/.config/opencode/mcp.json"

echo "MCP config written for claude, codex, cursor, opencode"
echo "restart any open CLI to pick up new servers"
