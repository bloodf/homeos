# AGENTS.md

Project-local instructions for any coding agent working in this repository.

## Project overview

HomeOS is a single-repository, script-only Linux home-server installer.

Source-of-truth paths:

| Area | Paths |
| --- | --- |
| Installer | `universal-installer/install.sh` |
| Smoke tests | `universal-installer/smoke-test.sh` |
| Example config | `universal-installer/homeos.conf.example` |
| Local commands | `Makefile` |
| CI | `.github/workflows/installer-ci.yml` |
| User docs | `README.md`, `universal-installer/README.md`, `docs/*.md` |
| Release notes | `release-notes/` |
| Portable agent assets | `.agents/agents/`, `.agents/skills/` |

Primary stack: Bash installer, ShellCheck, Docker-based Debian smoke tests, Markdown docs, GitHub Actions.

There are no application frontend, backend service, REST API, database migration, mobile, BLE, or hardware firmware layers in this repo as currently structured.

Generated, local, vendor, cache, and tool-state paths to avoid editing or documenting as source of truth:

- `.git/`
- `.worktrees/`
- `.claude/`
- `.omc/`
- `.pi/`
- `.pi-lens/`
- `.ruff_cache/`
- `__pycache__/`
- `.pytest_cache/`
- `.DS_Store`
- `progress.md`
- `subagent-review-*.md`

## Caution and verification

- Verify facts in source files before editing.
- Do not invent commands, architecture, test coverage, deployment targets, config keys, or release steps.
- Do not commit secrets. Treat copied `homeos.conf` files as sensitive unless they are sanitized examples.
- Cite exact paths in summaries and final responses.
- Do not claim tests, builds, links, pushes, or CI pass without fresh evidence.
- Prefer `README.md`, `Makefile`, `.github/workflows/installer-ci.yml`, `universal-installer/install.sh`, and `universal-installer/smoke-test.sh` over assumptions.

## Embedded engineering discipline

### Think before coding

Do not assume. Do not hide confusion. Surface tradeoffs before implementation.

Before changing files:

- State assumptions explicitly when they matter.
- If requirements have multiple valid interpretations, present them instead of silently choosing one.
- If a simpler approach exists, say so.
- Push back when the requested path seems risky, overcomplicated, or inconsistent with this repo.
- If something is unclear and blocks correct work, stop, name the ambiguity, and ask.

### Simplicity first

Write the minimum code/docs that solve the actual request. Nothing speculative.

Rules:

- Do not add features beyond what was asked.
- Do not add abstractions for single-use shell logic.
- Do not add flexibility/configurability that was not requested.
- Do not add defensive branches for unsupported scenarios unless existing installer patterns require it.
- If a solution is much larger than necessary, simplify before finalizing.

Self-check:

- Would a senior maintainer say this is overcomplicated?
- Can the same outcome be achieved with fewer moving parts?
- Does every new file/function/section have a real purpose in HomeOS?

### Surgical changes

Touch only what the task requires. Clean up only the mess created by your changes.

When editing existing code/docs:

- Do not improve unrelated code, comments, formatting, or docs.
- Do not refactor unrelated installer sections.
- Match existing Bash and Markdown style.
- If you notice unrelated dead code, stale docs, or bugs, mention them as follow-up instead of silently changing them.

When your changes create orphans:

- Remove imports, variables, functions, docs links, or config entries made unused by your change.
- Do not remove pre-existing dead code unless asked or required by the task.

Surgical-change test: every changed line should trace directly to the user request, verification requirement, or docs/process consistency.

### Goal-driven execution

Turn tasks into verifiable goals and loop until verified.

Examples:

- Installer behavior change → add/update a smoke test, watch it fail for the expected reason, implement, rerun.
- Config key change → update defaults, allowlist, checklist/help, dry-run output, docs, and deterministic smoke coverage where possible.
- CLI command change → update embedded CLI in `install.sh`, docs, smoke tests, and release notes if user-facing.
- Docs change → inspect source of truth, update docs, verify links/paths/commands, run formatting/link/config/secret checks.

These rules work when diffs are smaller, review is easier, and uncertainty is explicit instead of hidden.

## Mandatory TDD workflow

Use TDD for all behavior-changing work: features, bugfixes, refactors, migrations, API changes if ever added, UI behavior if ever added, and integrations.

Required loop:

1. Write or update a failing test first.
2. Run the targeted test and confirm it fails for the expected reason.
3. Implement the smallest change.
4. Run the targeted test and confirm it passes.
5. Refactor only if needed.
6. Run broader verification.
7. Update docs if behavior, contracts, commands, or config changed.

Allowed exceptions:

- docs-only changes
- comments/format-only changes
- mechanical generated output
- emergency hotfix explicitly waived by the user

State any exception in the final response.

Repo-specific test commands:

```bash
make check
make smoke
git diff --check
```

Use targeted commands before broad ones, for example:

```bash
shellcheck --severity=warning universal-installer/install.sh universal-installer/smoke-test.sh
bash -n universal-installer/install.sh
bash -n universal-installer/smoke-test.sh
INSTALLER_PATH="$PWD/universal-installer/install.sh" bash universal-installer/smoke-test.sh
```

`make smoke` requires Docker/OrbStack or another local Docker daemon.

## Best practices by layer

### Bash installer

- Keep `universal-installer/install.sh` ShellCheck-clean at warning severity.
- Keep `set -euo pipefail` compatible code paths.
- Quote variables unless Bash pattern matching requires otherwise.
- Avoid `eval` and command-substitution parsing for config.
- Preserve strict config allowlisting in `load_config`.
- Use `warn` for non-fatal third-party/environment failures and `die` only for hard blockers.
- Preserve idempotency: reruns should not break existing HomeOS-owned state.
- Preserve graceful degradation in containers and non-systemd environments.

### Config and secrets

- Keep config defaults in `install.sh`, `universal-installer/homeos.conf.example`, and docs aligned.
- Treat `TAILSCALE_AUTH_KEY`, `VAULTWARDEN_ADMIN_TOKEN`, `GRAFANA_ADMIN_PASSWORD`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, and `GOOGLE_API_KEY` as secret-bearing keys.
- Never document real token values. Use empty strings or obvious placeholders only.
- Do not weaken the `$VAR` / `${VAR}`-only expansion rule.

### Docker stacks and services

- Generated runtime files live under `/opt/homeos/stacks` on installed systems, not in this repo.
- Smoke tests should cover generated file content when deterministic.
- Do not require live third-party services, real systemd, or long-running installers in smoke tests.

### AI tooling and MCP isolation

- Keep shared skills/agents separate from per-tool MCP/plugin directories.
- Do not merge Claude Code, Codex, OpenCode, Pi, Cursor, Kimi, or Gemini MCP configs.
- Do not write API keys into MCP config files.
- Keep HomeOS-owned AI project links under the selected HomeOS namespace for each tool.

### Security-sensitive areas

- Review firewall, SSH hardening, local DNS, Caddy routes, generated secrets, config parsing, uninstall/purge, and third-party installer calls carefully.
- Prefer tests for parser safety, destructive command routing, bind addresses, and generated secret handling.

## Docs impact gate

Update docs whenever changes affect:

- commands/scripts/package metadata
- environment variables/config/secrets
- CLI options or command behavior
- API routes/contracts if an API is ever added
- deployment, Docker, CI, or release behavior
- architecture, package boundaries, or exports
- user-facing install/operation flows, route names, ports, permissions
- testing requirements or verification commands
- agent process/tooling

Every final response must include exactly one docs impact line:

```text
Docs: updated <files> because <reason>.
```

or:

```text
Docs: no update needed because <reason>.
```

## Git finalization requirement

Do not leave completed work only in the working tree.

Standard flow on `main`:

1. `git status --short`
2. review the diff
3. run verification
4. stage only intended files
5. commit with a clear message
6. `git pull --rebase origin main`
7. resolve conflicts if any
8. rerun impacted verification if conflicts occurred
9. `git push origin main`
10. report commit hash and push status

Branch/worktree flow:

1. create or switch to an isolated worktree/branch when work is risky, large, or requested
2. commit completed work in that branch/worktree
3. switch back to `main`
4. `git pull --rebase origin main`
5. merge the branch/worktree into `main`
6. run required verification
7. push `main`
8. clean up worktree/branch only if safe
9. report commit hash and push status

Before staging or committing, check:

```bash
git status --short
git diff --check
git diff --stat
git diff --cached --stat
```

Do not stage local tool state, generated junk, secrets, or unrelated work.
