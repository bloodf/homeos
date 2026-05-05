# Testing

HomeOS has one testable product surface in this repo: the Bash installer and its deterministic smoke tests.

## Test layers

| Layer | Command | Source |
| --- | --- | --- |
| Bash syntax | `bash -n universal-installer/install.sh` | `Makefile` target `syntax` |
| Smoke syntax | `bash -n universal-installer/smoke-test.sh` | `Makefile` target `syntax` |
| ShellCheck | `shellcheck --severity=warning universal-installer/install.sh universal-installer/smoke-test.sh` | `Makefile` target `shellcheck` |
| Static check bundle | `make check` | `Makefile` |
| Debian container smoke | `make smoke` | `Makefile`, `universal-installer/smoke-test.sh` |
| Whitespace check | `git diff --check` | Git |

## Smoke coverage

`universal-installer/smoke-test.sh` currently verifies deterministic paths including:

- config command-substitution injection does not execute
- uninstall argument parsing does not route to install
- help text documents config fallback behavior
- generated Grafana password, bind address, Prometheus target, and dashboard files
- local domain dnsmasq config generation
- AI project manifest-only mode, per-tool project links, MCP/plugin directory isolation, and README wording

Avoid smoke tests that require real external APIs, live systemd, a running Docker daemon inside the test container, or long third-party installers.

## TDD workflow for behavior changes

1. Add or update a focused smoke test or shell check.
2. Run the targeted command and confirm it fails for the expected reason.
3. Make the smallest installer/script/doc-help change.
4. Rerun the targeted command and confirm it passes.
5. Run `make check`.
6. Run `make smoke` when Docker is available.
7. Run `git diff --check` before commit.

Docs-only changes do not require TDD, but they still require verification.

## When a check cannot run

Report:

- command attempted
- failure reason
- risk of skipping
- recommended follow-up

Example:

```text
Skipped: make smoke — Docker daemon unavailable. Risk: Debian container smoke coverage not confirmed locally. Follow-up: rely on GitHub Actions or rerun with Docker/OrbStack running.
```
