# HomeOS AI integrations

HomeOS can install AI CLIs, Pi packages, `npx skills` skill packages, and a cloned AI project library. This page documents what is installed, where it comes from, and how isolation works.

## Isolation model

HomeOS separates three categories:

1. **Shared skills and agents** — reusable instructions that can be shared across compatible tools.
2. **Per-tool project links** — selected helper projects linked under each tool's own HomeOS namespace.
3. **Per-tool MCP/plugin state** — kept isolated. HomeOS does not rewrite global MCP config files.

Default per-tool namespaces:

| Tool        | HomeOS namespace             |
| ----------- | ---------------------------- |
| Claude Code | `~/.claude/homeos`           |
| OpenCode    | `~/.config/opencode/homeos`  |
| OpenAgent   | `~/.config/openagent/homeos` |
| Pi          | `~/.pi/agent/homeos`         |
| Codex       | `~/.codex/homeos`            |
| Cursor      | `~/.cursor/homeos`           |
| Gemini      | `~/.gemini/homeos`           |

Each namespace has separate `projects/`, `mcp/`, and `plugins/` directories. Shared skills and agents are symlinked from `/opt/homeos/ai/shared`.

## Interactive help UI

In interactive mode, if `whiptail` is available, the installer shows checklist dialogs for:

- HomeOS components
- AI skill packages
- AI skill target agents

Move the highlight over any checklist item to see help explaining what the item installs and what to think about before enabling it. Use `--yes` or `--unattended` to skip the checklist UI.

## `npx skills` installer

Enable with:

```bash
INSTALL_AI_SKILLS="yes"
```

Configure selections with semicolon-separated records:

```bash
AI_SKILL_INSTALLS="source|agent1,agent2|skill1,skill2;source|agents|skills"
```

Examples:

```bash
# Install one skill into Claude Code and Codex
AI_SKILL_INSTALLS="vercel-labs/skills|claude-code,codex|find-skills"

# Install every taste-skill skill into Claude Code, OpenCode, and Pi
AI_SKILL_INSTALLS="Leonxlnx/taste-skill|claude-code,opencode,pi|*"
```

Supported by `npx skills` on this machine: `claude-code`, `codex`, `opencode`, `pi`, `cursor`, `kimi-cli`, and `gemini-cli`. HomeOS accepts the short aliases `kimi` and `gemini` and normalizes them to `kimi-cli` and `gemini-cli`.

### Default skill packages

These defaults were derived from the local `~/.agents/.skill-lock.json` inventory and compatible skill directories.

| Source                                 | URL                                                       | Default skills                                                                                                      | Default agents                   | What it does                                                            |
| -------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------------------------------- | ----------------------------------------------------------------------- |
| `vercel-labs/skills`                   | <https://github.com/vercel-labs/skills>                   | `find-skills`                                                                                                       | Claude Code, Codex, OpenCode, Pi | Discover and install additional agent skills.                           |
| `vercel-labs/agent-skills`             | <https://github.com/vercel-labs/agent-skills>             | `vercel-react-best-practices`, `web-design-guidelines`, `vercel-composition-patterns`, `vercel-react-native-skills` | Claude Code, Codex, OpenCode, Pi | React, React Native, composition, and web design quality guidance.      |
| `anthropics/skills`                    | <https://github.com/anthropics/skills>                    | `frontend-design`                                                                                                   | Claude Code, Codex, OpenCode, Pi | Official Anthropic frontend design skill.                               |
| `Leonxlnx/taste-skill`                 | <https://github.com/Leonxlnx/taste-skill>                 | `*`                                                                                                                 | Claude Code, Codex, OpenCode, Pi | High-taste UI/design skills to reduce generic AI output.                |
| `obra/superpowers`                     | <https://github.com/obra/superpowers>                     | `brainstorming`, `subagent-driven-development`, `writing-plans`                                                     | Claude Code, Codex, OpenCode, Pi | Software development workflow methodology and skills.                   |
| `expo/skills`                          | <https://github.com/expo/skills>                          | Expo and React Native skills                                                                                        | Claude Code, Codex, OpenCode     | Expo app building, deployment, API routes, Tailwind, upgrades.          |
| `JuliusBrussee/caveman`                | <https://github.com/JuliusBrussee/caveman>                | `*`                                                                                                                 | Claude Code, Pi                  | Token-efficient communication, commit, review, and compression helpers. |
| `railwayapp/railway-skills`            | <https://github.com/railwayapp/railway-skills>            | `use-railway`                                                                                                       | Claude Code, Codex, OpenCode     | Railway infrastructure and deployment operations.                       |
| `callstackincubator/agent-skills`      | <https://github.com/callstackincubator/agent-skills>      | `github`, `react-native-best-practices`, `upgrading-react-native`, `validate-skills`                                | Claude Code, Codex, OpenCode     | GitHub workflows, React Native, and skill validation.                   |
| `wshobson/agents`                      | <https://github.com/wshobson/agents>                      | `tailwind-design-system`, `typescript-advanced-types`                                                               | Claude Code, Codex, OpenCode     | Tailwind design systems and advanced TypeScript types.                  |
| `vercel-labs/agent-browser`            | <https://github.com/vercel-labs/agent-browser>            | `agent-browser`                                                                                                     | Claude Code, Codex, OpenCode     | Browser automation, screenshots, scraping, and form/testing tasks.      |
| `browser-use/browser-use`              | <https://github.com/browser-use/browser-use>              | `browser-use`                                                                                                       | Claude Code, Codex, OpenCode     | Browser-use automation skill.                                           |
| `vercel-labs/next-skills`              | <https://github.com/vercel-labs/next-skills>              | `next-best-practices`                                                                                               | Claude Code, Codex, OpenCode     | Next.js best practices.                                                 |
| `hyf0/vue-skills`                      | <https://github.com/hyf0/vue-skills>                      | `vue-best-practices`, `vue-debug-guides`                                                                            | Claude Code, Codex, OpenCode     | Vue implementation and debugging guidance.                              |
| `MiniMax-AI/cli`                       | <https://github.com/MiniMax-AI/cli>                       | `mmx-cli`                                                                                                           | Claude Code, Codex, OpenCode     | MiniMax model/media CLI usage.                                          |
| `microsoft/azure-skills`               | <https://github.com/microsoft/azure-skills>               | `microsoft-foundry`                                                                                                 | Claude Code, Codex, OpenCode     | Microsoft Foundry agent deployment, eval, and optimization workflows.   |
| `nextlevelbuilder/ui-ux-pro-max-skill` | <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill> | `ui-ux-pro-max`                                                                                                     | Claude Code, Codex, OpenCode     | Broad UI/UX design intelligence.                                        |
| `laurigates/mcu-tinkering-lab`         | <https://github.com/laurigates/mcu-tinkering-lab>         | `esp32-debugging`                                                                                                   | Claude Code, Codex, OpenCode     | ESP32 and firmware debugging.                                           |

## AI project library

Enable with:

```bash
INSTALL_AI_PROJECTS="yes"
AI_PROJECTS="all"
AI_PROJECT_TOOLS="claude,opencode,openagent,pi,codex,cursor,gemini"
AI_PROJECT_TARGETS="" # optional per-project overrides
AI_PROJECT_INSTALL_MODE="clone" # or manifest-only
```

| Project            | URL                                               | Default target tools                                     | What it does                                                                 |
| ------------------ | ------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------- |
| oh-my-claudecode   | <https://github.com/Yeachan-Heo/oh-my-claudecode> | Claude Code, shared                                      | Teams-first multi-agent orchestration for Claude Code.                       |
| claude-mem         | <https://github.com/thedotmack/claude-mem>        | Claude Code, shared                                      | Claude Code plugin for session memory capture, compression, and reinjection. |
| A11Y.md            | <https://github.com/fecarrico/A11Y.md>            | Shared, Claude Code, OpenCode, Pi, Codex, Cursor, Gemini | Accessibility rules/context aligned with WCAG.                               |
| code-review-graph  | <https://github.com/tirth8205/code-review-graph>  | Shared, Claude Code, OpenCode, Pi, Codex, Cursor, Gemini | Local code knowledge graph for lower-token code review and coding context.   |
| hindsight          | <https://github.com/vectorize-io/hindsight>       | Shared, Claude Code, OpenCode, Pi, Codex, Cursor, Gemini | Agent memory that learns from previous work.                                 |
| taste-skill        | <https://github.com/Leonxlnx/taste-skill>         | Shared, Claude Code, OpenCode, Pi, Codex, Cursor         | Design taste skills for more polished UI output.                             |
| portless           | <https://github.com/vercel-labs/portless>         | Shared, Claude Code, OpenCode, Pi, Codex, Cursor, Gemini | Stable named local URLs instead of remembering port numbers.                 |
| Matt Pocock skills | <https://github.com/mattpocock/skills>            | Shared, Claude Code, OpenCode, Pi, Codex, Cursor, Gemini | Practical engineering skills from Matt Pocock's setup.                       |
| cinsights          | <https://github.com/deepankarm/cinsights>         | Shared, Claude Code, OpenCode, Pi, Codex, Cursor, Gemini | Coding-agent insights for teams.                                             |
| claude-context     | <https://github.com/zilliztech/claude-context>    | Claude Code, shared                                      | Code search MCP/context tool backed by Zilliz/Milvus.                        |
| ClawTeam           | <https://github.com/HKUDS/ClawTeam>               | Claude Code, shared                                      | Agent swarm automation for coding workflows.                                 |
| heretic            | <https://github.com/p-e-w/heretic>                | Shared, Claude Code, OpenCode, Pi, Codex, Cursor         | Automatic censorship-removal helper for language models.                     |
| OpenViking         | <https://github.com/volcengine/OpenViking>        | Shared, OpenCode, OpenAgent, Claude Code                 | Context database for AI agents: memory, resources, and skills.               |
| impeccable         | <https://github.com/pbakaus/impeccable>           | Shared, Claude Code, OpenCode, Cursor                    | Design language to improve AI harness design output.                         |
| agency-agents      | <https://github.com/msitarzewski/agency-agents>   | Shared, Claude Code, OpenCode, Pi                        | Specialized agency-style agents.                                             |
| oh-my-openagent    | <https://github.com/code-yeongyu/oh-my-openagent> | OpenAgent, shared                                        | OpenAgent harness configuration and workflow project.                        |
| shannon            | <https://github.com/KeygraphHQ/shannon>           | Shared, Claude Code, OpenCode, Pi, Codex                 | Autonomous white-box web/API pentester.                                      |
| hive               | <https://github.com/aden-hive/hive>               | Shared, Claude Code, OpenCode, Pi, Codex, Cursor         | Multi-agent harness for production AI.                                       |
| superpowers        | <https://github.com/obra/superpowers>             | Shared, Claude Code, OpenCode, Pi, Codex, Cursor, Gemini | Agentic skills framework and software development methodology.               |
| AgentTower         | <https://github.com/opensoft/AgentTower>          | Shared, OpenCode, OpenAgent, Claude Code                 | Local tmux-based AI agent workflow control tower.                            |

## Local inventory used for defaults

This inventory was taken from the maintainer workstation and sanitized to avoid secret values.

### Skill counts

| Location                    | Count | Notes                                       |
| --------------------------- | ----: | ------------------------------------------- |
| `~/.agents/skills`          |   161 | Global skill registry used by `npx skills`. |
| `~/.claude/skills`          |   123 | Claude Code skill install location.         |
| `~/.codex/skills`           |   111 | Codex skill install location.               |
| `~/.config/opencode/skills` |     1 | OpenCode skill install location.            |
| `~/.pi/agent/skills`        |    15 | Pi skill install location.                  |

### Agent counts

| Location                    | Count | Notes                                         |
| --------------------------- | ----: | --------------------------------------------- |
| `~/.claude/agents`          |    31 | GSD specialist agents.                        |
| `~/.codex/agents`           |    82 | GSD plus Codex-specific specialist agents.    |
| `~/.config/opencode/agents` |    31 | GSD specialist agents for OpenCode/OpenAgent. |

### MCP inventory

HomeOS records this inventory in documentation only. It does not modify MCP server behavior.

| Tool        | MCP servers found                                                                                                                                                                                                                                          |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pi          | MiniMax, web-search-prime, web-reader, zread, zai-mcp-server                                                                                                                                                                                               |
| Claude Code | minimax, zai-mcp-server, web-search-prime, web-reader, zread, gitnexus; local enabled mcp.json servers include filesystem, sequential-thinking, fetch, git, context7, markitdown, chrome-devtools, playwright, expo, next-devtools, iterm, local-rag, time |
| Codex       | context7, filesystem, sequentialthinking, git, time, fetch, markitdown, chrome-devtools, expo, next-devtools, iterm, local-rag, claude-context, omx_state, omx_memory, omx_code_intel, omx_trace, omx_wiki, gitnexus                                       |
| OpenCode    | minimax, zai-mcp-server, web-search-prime, web-reader, zread, playwright, sequential-thinking, context7, filesystem, git, time, fetch, markitdown, chrome-devtools, expo, next-devtools, iterm, local-rag, gitnexus                                        |
| Kimi        | sequential-thinking, context7, filesystem, git, time, fetch, markitdown, iterm, local-rag, claude-context                                                                                                                                                  |

## What HomeOS deliberately does not do

- It does not copy Claude Code config into OpenCode or vice versa.
- It does not merge MCP server configs across tools.
- It does not write API keys into MCP config files.
- It does not treat unsupported `npx skills` targets as installed.
- It does not install every local private/custom skill unless it has a source package or is explicitly added to `AI_SKILL_INSTALLS`.
