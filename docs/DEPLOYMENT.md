# Deployment

HomeOS deployment is the installer execution path. This repository does not contain a separate web app, package registry publish step, container image pipeline, Kubernetes manifests, Vercel/Railway/Fly config, or mobile app-store deployment config.

## Supported deployment target

The supported target is an existing Linux machine:

- Debian 12+
- Ubuntu 22.04 LTS+
- Fedora 38+
- RHEL/Rocky/Alma 9+

See `docs/INSTALLATION.md` for install modes and supported environments.

## Installer delivery

Published docs use the raw GitHub installer URL from `main`:

```bash
curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh | sudo bash
```

Local development can run:

```bash
sudo bash universal-installer/install.sh --dry-run
sudo bash universal-installer/install.sh --config /etc/homeos/homeos.conf --unattended
```

## Update path

Installed systems use:

```bash
homeos update
```

The embedded CLI downloads the latest `main` installer and reuses `/var/lib/homeos/config-path` when available.

## CI/CD

GitHub Actions workflow:

- `.github/workflows/installer-ci.yml`

Triggers:

- pushes to `main` that touch `universal-installer/**`, `Makefile`, or the workflow file
- pull requests touching those paths
- manual `workflow_dispatch`

Jobs:

- `static`: installs ShellCheck and runs `make check`
- `smoke`: runs `make smoke` after static checks

Docs-only changes outside the workflow paths do not currently trigger this CI workflow.

## Release deployment

Releases are Git tags plus GitHub Releases. Follow `docs/RELEASE-PROCESS.md` for version updates, validation, tagging, and release creation.

Do not tag until local checks and CI are green unless explicitly cutting a pre-release for debugging.

## Unknowns

No separate production deployment automation was found beyond raw GitHub installer delivery, `homeos update`, GitHub Actions validation, tags, and GitHub Releases.
