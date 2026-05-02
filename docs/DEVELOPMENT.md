# Development

How to build, modify, and contribute to HomeOS.

## Prerequisites

- Docker (or OrbStack on macOS).
- ~2 GB RAM, ~3 GB free disk.
- `make`.
- For QEMU smoke tests: `qemu-system-x86_64` (Linux) or `qemu-system-aarch64`
  (macOS arm64).

The build runs **inside** a Docker container (`debian:trixie-slim` +
`xorriso`), so the host OS doesn't need any of those tools installed
locally.

## First build

```bash
git clone https://github.com/bloodf/homeos
cd homeos
make iso
```

This:

1. Warns if `secrets/authorized_keys` is empty (public-distro mode).
2. Refreshes GitHub tool SHAs (`make pin-tools`).
3. Builds the `homeos-builder` Docker image (`make builder`).
4. Downloads the upstream Debian netinst ISO and verifies its SHA256
   (`make base-iso`).
5. Repacks the ISO with preseed + bootstrap (`build/repack-iso.sh`).
6. Writes `dist/homeos-debian-13.4-amd64.iso` and a `.sha256` file.

Total time: ~90 seconds on a recent laptop (after the first build — the
builder image and base ISO are cached).

## ARM64 build

```bash
make ARCH=arm64 iso
```

Produces `dist/homeos-debian-13.4-arm64.iso`. Native arm64 macOS hosts
(M1/M2/M3) build this without emulation. amd64 hosts build it through
Docker's QEMU layer.

## Make targets

| Target                | What                                                                           |
| --------------------- | ------------------------------------------------------------------------------ |
| `make help`           | Show all targets                                                               |
| `make builder`        | Build the Docker builder image                                                 |
| `make base-iso`       | Download + verify upstream Debian netinst                                      |
| `make pin-tools`      | Refresh GitHub tool commit SHAs                                                |
| `make refresh-pins`   | Print latest SHAs without writing                                              |
| `make iso`            | Full build (default for `ARCH=amd64`)                                          |
| `make ARCH=arm64 iso` | Full build for arm64                                                           |
| `make qemu-test`      | Boot the built ISO in QEMU; reserved for orchestrator-approved v1.0 validation |
| `make clean`          | Wipe `dist/` and QEMU disk images                                              |
| `make check-pubkey`   | Warn if `secrets/authorized_keys` is missing                                   |

## Repository layout

```
homeos/
├── Makefile
├── README.md
├── docs/                       # documentation
├── build/
│   ├── Dockerfile              # debian:trixie-slim + xorriso
│   ├── download-base-iso.sh    # fetch + SHA256-verify Debian netinst
│   ├── repack-iso.sh           # xorriso pipeline
│   └── refresh-pins.sh         # GitHub tool SHA refresher
├── preseed/
│   ├── preseed.cfg             # full unattended d-i answers
│   ├── grub.cfg                # auto-boot, no menu
│   └── isolinux.cfg            # legacy BIOS boot path
├── bootstrap/
│   ├── install.yml             # top-level Ansible play
│   ├── requirements.yml        # ansible-galaxy collections
│   ├── vars/
│   │   ├── main.yml            # versions, github_tools, firewall
│   │   ├── stacks.yml          # docker-compose stack list
│   │   └── nas_disks.yml       # USB drives (runtime-edited)
│   ├── files/                  # static files copied verbatim
│   ├── templates/              # Jinja2 templates
│   └── roles/                  # Ansible roles
├── secrets/
│   └── authorized_keys         # gitignored — your pubkey
└── .github/workflows/
    └── build-iso.yml           # CI matrix amd64 + arm64
```

## Modifying a role

```bash
$EDITOR bootstrap/roles/<name>/tasks/main.yml
make iso
# flash to USB and re-test, OR test in-place on a running box:
sudo homeos config rerun-bootstrap
```

Roles must remain idempotent — every task should use `state: present`,
`creates:`, or explicit `when:` conditions so re-runs are no-ops.

## Adding a new GitHub tool

1. Append to `github_tools` in `bootstrap/vars/main.yml`:
   ```yaml
   - name: my-new-tool
     repo: example/my-new-tool
     ref: HEAD # `make pin-tools` will replace
     install: npm # one of: npm, pnpm, pipx, cargo, none
   ```
2. `make pin-tools` to write a real SHA.
3. `make iso` to rebuild.

Or test in-place:

```bash
ansible-playbook -i localhost, -c local \
  /opt/homeos/bootstrap/install.yml --tags github-tools
```

## Adding a new Docker stack

1. Create `bootstrap/templates/<stack>-compose.yml.j2` with your compose.
2. Append to `stacks` in `bootstrap/vars/stacks.yml`:
   ```yaml
   - name: <stack>
     enabled: true
     watchtower: true # opt into label-based auto-update
   ```
3. `make iso` (or `homeos config rerun-bootstrap` on a running box).

## Refreshing tool SHAs

```bash
# print without writing:
make refresh-pins

# write into bootstrap/vars/main.yml:
make pin-tools
```

`refresh-pins.sh` calls the GitHub API for each entry in `github_tools` and
fetches the current `HEAD` commit. Runs locally with no auth (rate-limited
to 60 req/h) or with `GITHUB_TOKEN` set (5000 req/h).

CI sets `GITHUB_TOKEN` automatically.

## Testing

### Ansible syntax check

```bash
docker run --rm -v "$PWD:/work" homeos-builder:latest \
  ansible-playbook --syntax-check /work/bootstrap/install.yml
```

### QEMU final validation

```bash
make qemu-test
```

QEMU is reserved for orchestrator-approved v1.0 validation. The v0.5-v0.9
milestones use source-level checks and GitHub release builds only; they do not
run local VM boots. The v1.0 checklist requires a visible supervised QEMU run
that proves the ISO boots, unattended install completes, SSH works, firstboot
bootstrap finishes, `homeos doctor` passes or only documented virtual-hardware
limitations fail, audit/gate flows work, secure mode does not lock out SSH, and
core services survive reboot.

See `V1-QEMU-TESTING-PROMPT.md` for the full runbook.

### CI

`.github/workflows/build-iso.yml` is intentionally tag/manual-only. `v*` tags and
`workflow_dispatch` build amd64 + arm64 in parallel, run static policy checks,
verify committed GitHub tool pins, and attach both ISOs plus `.sha256` files to
the GitHub release. Branch pushes and pull requests do not trigger ISO builds.

## Releasing

1. Refresh tool SHAs: `make pin-tools`.
2. Commit + push.
3. Verify CI green: `gh run watch`.
4. Tag: `git tag v0.x.0 && git push --tags`.
5. CI builds + attaches ISOs to the release page.

## Coding conventions

- **Bash**: `set -euo pipefail` (with one documented exception in
  `refresh-pins.sh` — `awk exit` triggers SIGPIPE under pipefail).
- **Ansible**: 2-space indent, lowercase module names, FQCNs where
  collection-provided.
- **Jinja2**: prefer explicit defaults (`{{ var | default('') }}`).

## Contributing

PRs welcome. See README → "Building from source" for the build loop. Please:

- Run `make iso` locally before opening a PR.
- Note any new outbound network dependencies in [HARDWARE.md](HARDWARE.md).
- Update the relevant doc in `docs/`.
