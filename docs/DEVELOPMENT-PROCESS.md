# Development process

Use this process for every HomeOS change.

## Principles

1. Keep HomeOS script-only.
2. Prefer explicit Bash over hidden magic.
3. Keep the installer idempotent and safe to re-run.
4. Preserve graceful degradation in containers/non-systemd environments.
5. Never weaken config parser safety.
6. Keep MCP/plugin behavior isolated per AI tool.
7. Update docs and tests with code changes.

## Branch workflow

```bash
git checkout main
git pull --ff-only
git checkout -b <type>/<short-name>
```

For small maintainer-only changes, direct commits to `main` are acceptable after local checks pass and CI is watched.

## Change checklist

Before editing:

- Read the relevant docs in `docs/` and `universal-installer/README.md`.
- Read the relevant installer section in `universal-installer/install.sh`.
- Confirm the change does not reintroduce ISO/QEMU/preseed/bootstrap paths.

While editing:

- Keep ShellCheck clean at `--severity=warning`.
- Use `warn` for non-fatal third-party/environment failures.
- Use `die` only for hard blockers.
- Quote variables.
- Avoid `eval`.
- Avoid shell background patterns for installer-managed services.
- Keep all config keys in the allowlist inside `load_config`.
- If a new component is added, include it in:
  - defaults
  - config allowlist
  - interactive checklist/help
  - dry-run output
  - minimal-mode disabling if appropriate
  - install flow
  - docs
  - smoke tests when deterministic

## Testing locally

```bash
make check
make smoke
git diff --check
```

`make check` must always pass before commit.

`make smoke` requires Docker/OrbStack running locally. It should pass before pushing unless the change is docs-only and CI will verify.

## Smoke-test requirements

Add smoke coverage for deterministic behavior such as:

- parser safety
- generated file content
- config flags
- route file generation
- manifest generation
- version output
- command dispatch behavior

Avoid smoke tests that require real external APIs, real systemd, or long-running third-party installers.

## Documentation requirements

Update docs when changing:

- config keys
- default behavior
- ports/network behavior
- installed components
- CLI commands
- security model
- AI skill/project defaults
- release process

Docs to consider:

- `README.md`
- `universal-installer/README.md`
- `universal-installer/homeos.conf.example`
- `docs/README.md`
- topic-specific docs under `docs/`
- `release-notes/vX.Y.Z.md`

## Commit style

Use short conventional-style subjects:

```text
feat(installer): add selectable AI skills
docs: add operations and release process
fix(installer): harden config parser
ci: add installer smoke checks
```

## Review checklist

Before commit:

- [ ] `make check` passes
- [ ] `make smoke` passes or reason is documented
- [ ] `git diff --check` passes
- [ ] docs updated
- [ ] no secrets committed
- [ ] no legacy image/ISO pipeline files added
- [ ] release notes updated for user-facing changes

After push:

- [ ] Watch GitHub Actions
- [ ] Fix failures immediately or revert
