---
name: project-git-finalize
description: Use when HomeOS work is ready to finish, before claiming completion, committing, rebasing, pushing, or reporting final status.
---

# Project Git Finalize

Completed HomeOS work must be committed and pushed to `origin/main` unless blocked.

## Standard main flow

```bash
git status --short
git diff --stat
git diff --check
make check
# make smoke when Docker is available or behavior changed
git add <intended files>
git diff --cached --stat
git commit -m "docs: add project agent guidance"
git pull --rebase origin main
# rerun impacted checks if conflicts occurred
git push origin main
git rev-parse --short HEAD
```

## Branch/worktree flow

Use when work is risky, large, or requested:

1. create/switch branch or worktree
2. commit completed work there
3. return to `main`
4. `git pull --rebase origin main`
5. merge branch/worktree into `main`
6. rerun required checks
7. push `main`
8. clean up only if safe

## Staging guard

Before commit, ensure staged files exclude:

- secrets or real `homeos.conf`
- `.DS_Store`
- `.claude/`, `.omc/`, `.pi/`, `.pi-lens/`
- `.worktrees/`
- caches such as `.ruff_cache/`, `.pytest_cache/`, `__pycache__/`
- unrelated user changes

## Final report requirements

Report:

- commit hash
- push status
- verification commands and results
- skipped checks and why
- docs impact line
