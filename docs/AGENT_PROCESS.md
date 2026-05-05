# Agent process

This process applies to every coding agent working on HomeOS. Root `AGENTS.md` is the authority; this file is the shorter operational checklist.

## Source-first workflow

1. Read the relevant source of truth:
   - installer behavior: `universal-installer/install.sh`
   - config defaults: `universal-installer/homeos.conf.example`
   - validation: `Makefile`, `universal-installer/smoke-test.sh`
   - CI: `.github/workflows/installer-ci.yml`
   - docs index: `docs/README.md`
2. State any assumption that affects the change.
3. Make the smallest scoped edit.
4. Verify with targeted checks, then broader checks.
5. Update docs when behavior, commands, config, tests, CI, release, or agent process changes.
6. Commit, rebase from `origin/main`, and push `origin/main` unless explicitly blocked.

## Required TDD for behavior changes

For installer, CLI, config, security, or integration behavior:

1. Add or update a deterministic test in `universal-installer/smoke-test.sh` when practical.
2. Run the targeted command and confirm failure for the expected reason.
3. Implement the smallest change.
4. Rerun the targeted command and confirm it passes.
5. Run `make check`.
6. Run `make smoke` when Docker is available.

Docs-only changes do not require TDD, but they still require link/path/command/config/secret verification.

## Verification ladder

Use the narrowest useful check first:

```bash
bash -n universal-installer/install.sh
bash -n universal-installer/smoke-test.sh
shellcheck --severity=warning universal-installer/install.sh universal-installer/smoke-test.sh
make check
make smoke
git diff --check
```

`make smoke` requires Docker/OrbStack. If it cannot run locally, record the attempted command, why it failed, and the risk.

## Docs gate

Before final response, answer:

- Did commands or CLI help change?
- Did config keys/defaults/secrets change?
- Did install/uninstall/update behavior change?
- Did service ports, bind addresses, firewall, DNS, Docker, AI tooling, or MCP behavior change?
- Did tests, CI, release process, or agent process change?

If yes, update the relevant docs and final response line:

```text
Docs: updated <files> because <reason>.
```

If no:

```text
Docs: no update needed because <reason>.
```

## Git finalization

Use the `project-git-finalize` skill in `.agents/skills/project-git-finalize/SKILL.md` before claiming completion.
