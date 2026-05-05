---
name: feature-docs-gate
description: Use before completing HomeOS feature, bugfix, refactor, config, test, CI, deployment, security, or agent-process changes.
---

# Feature Docs Gate

Before final response, decide whether docs changed or should have changed.

## Questions

Answer every item:

- Behavior changed?
- Commands or CLI help changed?
- Config keys/defaults/secrets changed?
- Install/update/uninstall flow changed?
- Ports, firewall, DNS, Docker, AI tooling, or MCP isolation changed?
- Architecture/package boundary changed?
- Tests or verification commands changed?
- CI/deployment/release process changed?
- Agent process/assets changed?

## If yes

Update the relevant docs from the docs map in `.agents/skills/project-docs-sync/SKILL.md`.

Then verify:

```bash
git diff --check
make check
```

Run `make smoke` if behavior changed and Docker is available.

## If no

Do not edit docs just to satisfy a checklist. Say why no docs update was needed.

## Required final response line

Use exactly one:

```text
Docs: updated <files> because <reason>.
```

or:

```text
Docs: no update needed because <reason>.
```
