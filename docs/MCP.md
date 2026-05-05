# MCP guidance

HomeOS documents and installs AI tooling that may include MCP-related directories, but this repository does not require a committed project-level MCP server configuration to develop, test, or release the installer.

## Repository policy

- Do not commit private MCP tokens, personal filesystem paths, private endpoints, or machine-specific config.
- Do not merge MCP configs across tools.
- Do not copy Claude Code MCP config into Codex/OpenCode/Pi/Cursor/Gemini or vice versa.
- Keep HomeOS shared skills/agents separate from per-tool `mcp/` and `plugins/` directories.
- Use ignored local files for private overrides if a tool supports them, for example `.mcp.local.json`.

## HomeOS installed-system behavior

When AI project integration is enabled, HomeOS creates per-tool HomeOS namespaces such as:

| Tool | Namespace |
| --- | --- |
| Claude Code | `~/.claude/homeos` |
| OpenCode | `~/.config/opencode/homeos` |
| OpenAgent | `~/.config/openagent/homeos` |
| Pi | `~/.pi/agent/homeos` |
| Codex | `~/.codex/homeos` |
| Cursor | `~/.cursor/homeos` |
| Gemini | `~/.gemini/homeos` |

Each namespace can contain `projects/`, `mcp/`, and `plugins/`. Shared skills and agents are exposed through `/opt/homeos/ai/shared`; MCP/plugin state remains per tool.

## Recommended agent behavior

For repo work, prefer normal local tools first:

```bash
make check
make smoke
git diff --check
```

Use MCP tools only when they are public-safe and useful for the task. If an MCP tool needs credentials or private local paths, configure it outside the repository.

## Why no committed `.mcp.json`

No project-required MCP servers were found. A committed `.mcp.json` would either be empty or risk encoding personal tool preferences as project requirements. Add one only when the repo gains a public-safe, reproducible MCP need.
