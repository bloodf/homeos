# Agent capabilities

HomeOS keeps portable, project-local agent assets under `.agents/` so they can be reused by different coding tools.

## Canonical asset paths

```text
.agents/
├── agents/
└── skills/
```

Do not put canonical HomeOS process instructions under tool-specific folders such as `.claude/`, `.codex/`, `.cursor/`, `.pi/`, or `.github/`. Thin adapters may point to `.agents/` if a tool needs them, but `.agents/` remains the source of truth.

## Project-local skills

| Skill | Purpose |
| --- | --- |
| `.agents/skills/project-docs-sync/SKILL.md` | Decide and perform docs updates after code/config/process changes. |
| `.agents/skills/feature-docs-gate/SKILL.md` | Final docs-impact gate before completing feature/bugfix/refactor/config/test work. |
| `.agents/skills/project-tdd-workflow/SKILL.md` | Enforce HomeOS-specific TDD and verification commands. |
| `.agents/skills/project-git-finalize/SKILL.md` | Commit, rebase, push, and report completed work safely. |

## Project-local roles

| Role | Use when |
| --- | --- |
| `.agents/agents/docs-maintainer.md` | Updating or auditing README/docs/agent process. |
| `.agents/agents/tdd-implementer.md` | Changing installer, CLI, config parser, smoke tests, or integrations. |
| `.agents/agents/installer-guardian.md` | Reviewing installer structure, idempotency, component boundaries, or generated CLI changes. |
| `.agents/agents/security-reviewer.md` | Reviewing config parsing, secrets, network exposure, firewall, SSH, uninstall/purge, MCP isolation. |
| `.agents/agents/release-verifier.md` | Preparing tags/releases or validating release readiness. |

## Tooling boundaries

HomeOS can install AI CLIs, skills, and MCP-related project directories on target systems, but this repository does not require a project-level MCP server config to build or test.

Use public-safe tooling only in committed config. Private MCP tokens, local paths, and personal endpoints belong in ignored local files, not in this repo.
