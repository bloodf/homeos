---
name: project-tdd-workflow
description: Use when changing HomeOS installer behavior, CLI behavior, config parsing/defaults, security-sensitive flows, integrations, or smoke-test-covered behavior.
---

# Project TDD Workflow

HomeOS behavior changes require red-green-refactor.

## Red

Add/update the smallest deterministic check first, usually in `universal-installer/smoke-test.sh`.

Run a targeted command and confirm failure for the expected reason:

```bash
INSTALLER_PATH="$PWD/universal-installer/install.sh" bash universal-installer/smoke-test.sh
```

For syntax-only changes:

```bash
bash -n universal-installer/install.sh
bash -n universal-installer/smoke-test.sh
```

## Green

Make the smallest change in `universal-installer/install.sh`, docs, or config example. Rerun the targeted command until it passes.

## Refactor

Refactor only if it reduces complexity without widening scope. Rerun the targeted command after each refactor.

## Broader verification

```bash
make check
make smoke
git diff --check
```

`make smoke` requires Docker/OrbStack. If unavailable, record the attempted command and risk.

## Exceptions

TDD is not required for:

- docs-only changes
- comments/format-only changes
- mechanical generated output
- emergency hotfix explicitly waived by the user

State any exception in the final response.
