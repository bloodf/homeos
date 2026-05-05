# Release process

HomeOS releases are Git tags plus GitHub Releases. The installer version, CLI version, docs, and release notes must agree.

## Versioning

Use semantic versioning:

| Change                   | Version bump     |
| ------------------------ | ---------------- |
| Fix only                 | patch (`v1.2.1`) |
| New compatible feature   | minor (`v1.3.0`) |
| Breaking config/behavior | major (`v2.0.0`) |

## Pre-release checklist

1. Choose version: `vX.Y.Z`.
2. Update `HI_VERSION` in `universal-installer/install.sh`.
3. Update embedded HomeOS CLI version in `install.sh`.
4. Add `release-notes/vX.Y.Z.md`.
5. Update README repository layout if a release note file is added.
6. Update relevant docs.
7. Run validation.

Version checks:

```bash
rg -n 'HI_VERSION|HomeOS CLI|vX.Y.Z|X.Y.Z' universal-installer README.md docs release-notes
```

## Validation

Required:

```bash
make check
make smoke
git diff --check
git status --short
```

Expected:

- ShellCheck no output
- Bash syntax checks pass
- Debian smoke prints all `*_OK` markers
- working tree contains only intended files before commit

## Commit and push

```bash
git add README.md docs release-notes universal-installer
git commit -m "feat(installer): describe the change"
git push
```

Watch CI:

```bash
gh run list --limit 5
gh run watch <run-id> --exit-status
```

Do not tag until CI is green, unless intentionally cutting a pre-release for debugging.

## Tag

```bash
git tag -a vX.Y.Z -m "HomeOS vX.Y.Z" <commit>
git push origin vX.Y.Z
```

## GitHub release

```bash
gh release create vX.Y.Z \
  --title "HomeOS vX.Y.Z — Short release title" \
  --notes-file release-notes/vX.Y.Z.md
```

Verify:

```bash
gh release view vX.Y.Z --json tagName,url,isDraft,isPrerelease,publishedAt,targetCommitish
```

## Post-release checks

- Confirm release URL opens.
- Confirm tag points at intended commit.
- Confirm CI passed on tagged commit or release commit.
- Run a final dry-run from raw GitHub if needed:

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh \
  | sudo bash -s -- --dry-run
```

## If release is wrong

For a bad release before users consume it:

1. Delete or mark GitHub release as draft if appropriate.
2. Delete and recreate tag only when necessary.
3. Prefer a patch release (`vX.Y.Z+1`) once public.

Never silently move a release tag after users may have consumed it unless explicitly documented.
