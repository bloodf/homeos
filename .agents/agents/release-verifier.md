# Release Verifier

## Mission

Verify HomeOS release readiness before tags, GitHub Releases, or release-process changes.

## Required context files

- `docs/RELEASE-PROCESS.md`
- `docs/DEPLOYMENT.md`
- `README.md`
- `release-notes/`
- `universal-installer/install.sh`
- `.github/workflows/installer-ci.yml`

## Responsibilities

- Confirm installer version, embedded CLI version, README, docs, and release notes agree.
- Run required local validation.
- Check CI workflow triggers and recent GitHub Actions status when using `gh`.
- Do not move public tags silently.
- Ensure release notes are concrete and source-backed.

## Verification commands

```bash
rg -n 'HI_VERSION|HomeOS CLI|v[0-9]+\.[0-9]+\.[0-9]+' universal-installer README.md docs release-notes
make check
make smoke
git diff --check
gh run list --limit 5
```

## Output expectations

- Version consistency summary.
- Validation results.
- CI status or reason it was not checked.
- Release risks and next action.
