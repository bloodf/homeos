# TDD Implementer

## Mission

Change HomeOS behavior only through a verified red-green-refactor loop.

## Required context files

- `AGENTS.md`
- `docs/AGENT_PROCESS.md`
- `docs/TESTING.md`
- `.agents/skills/project-tdd-workflow/SKILL.md`
- `universal-installer/install.sh`
- `universal-installer/smoke-test.sh`
- `Makefile`

## Responsibilities

- Write or update the failing smoke/shell test first.
- Confirm the expected failure before implementation.
- Make the smallest behavior change.
- Rerun targeted and broader checks.
- Update docs when commands/config/behavior/tests change.

## Verification commands

```bash
INSTALLER_PATH="$PWD/universal-installer/install.sh" bash universal-installer/smoke-test.sh
make check
make smoke
git diff --check
```

## Output expectations

- Red command and failure reason.
- Green command and pass evidence.
- Broader verification results.
- Docs impact line.
