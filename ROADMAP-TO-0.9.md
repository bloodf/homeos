# HomeOS Roadmap to v0.9

This roadmap supersedes the earlier v1.0 expectation. The new policy is:

- **This policy supersedes HANDOFF.md QEMU/full-smoke requirements for all v0.5-v0.9 worker/subagent work.** HANDOFF.md remains useful background, but workers must follow this roadmap when validation scope conflicts.
- **v0.7 = bootstrap fixes.** It is the milestone for making unattended install and first-boot bootstrap reliable enough to prepare for release-candidate hardening.
- **v1.0 = final full QEMU / full ISO validation only.** v1.0 is not a feature milestone. It is the final proof gate after v0.9 is complete.
- **No worker/subagent may run QEMU before v1.0.** This includes `qemu-system-*`, `make qemu-test`, full VM boots, or any equivalent ISO VM smoke. Only the orchestrator may run final QEMU validation at v1.0.
- **ISO builds are orchestrator-controlled before v1.0.** Workers may propose an ISO build to the orchestrator when evidence suggests it is useful, but must not run `make iso` or equivalent unless the orchestrator explicitly assigns that build task.

## Execution rules for all agents

- Executing agents **must mark completed items `[x]` in this file** with a short evidence/date note on the same bullet or immediately below it.
  - Example: `- [x] Implemented command dispatch — evidence: commit abc1234, static check passed, 2026-05-01.`
- Do not add `TODO`, `FIXME`, or `XXX` markers anywhere in source files or docs. All incomplete work must remain tracked as unchecked items in this roadmap.
- Workers do not commit, tag, push, publish releases, run QEMU, or run orchestrator-controlled ISO builds. The orchestrator owns git, release operations, ISO-build approval, and v1.0 final validation.
- Workers should run static or targeted validations only: `bash -n`, YAML parsing, unit-style shell harnesses, `ansible-playbook --syntax-check` when installed, focused grep/schema checks, and local CLI dry-runs that do not boot a VM.
- Parallel workers must not all edit roadmap/docs/release notes concurrently unless the orchestrator assigns non-overlapping sections or separate worktrees. When updating ROADMAP checkboxes, keep edits minimal and scoped to the worker's assigned checklist section.
- Reviewers should not implement unless explicitly asked. They should report concrete findings with file paths and smallest safe fixes.
- Every changed behavior must be reflected in README/docs/release notes before the milestone is considered complete.

## v0.5.0 — Cosmos Docker socket shim release finalization

Goal: finalize and release the already-started Cosmos Docker socket shim work. Cosmos should mount `/var/run/cosmos-docker.sock` instead of the real Docker socket, and mutating Docker API calls should be audited before forwarding.

### Implementation and correctness

- [x] Confirm `bootstrap/roles/cosmos/files/homeos-cosmos-docker-shim` exists, is executable, and has `set -euo pipefail` equivalent for its implementation — evidence: executable Python shim, `python3 -m py_compile` passed, 2026-05-01.
- [x] Confirm the old v0.4 Cosmos log-tail audit service is removed or disabled cleanly, with no stale references to the removed script — evidence: Ansible and CLI disable `homeos-cosmos-audit.service`; no legacy script references found, 2026-05-01.
- [x] Confirm shim forwards Docker API traffic to `/var/run/docker.sock` and listens on `/var/run/cosmos-docker.sock` — evidence: shim constants and local Unix-socket harness passed, 2026-05-01.
- [x] Confirm shim audits mutating Docker methods/paths before forwarding: `POST`, `PUT`, `DELETE` for containers, images, networks, volumes — evidence: resource/method filter in shim plus `POST /containers/...` harness, 2026-05-01.
- [x] Confirm audit entries use `cmd: "cosmos:<verb>:<resource>"`, `verdict: "BYPASS"`, and include a body/hash summary without leaking large raw payloads — evidence: shim emits `cosmos:post:containers` with body hash/size/truncation metadata; harness verified raw body redaction, 2026-05-01.
- [x] Confirm non-mutating calls like `GET /containers/json` pass through unchanged and are not noisy in the audit log — evidence: local Unix-socket harness verified GET proxy with no audit line, 2026-05-01.
- [x] Confirm `homeos-cosmos-docker-shim.service` starts before/with Cosmos when Cosmos is enabled and stops when Cosmos is disabled — evidence: Ansible unit ordering and CLI on/off systemctl flow reviewed, 2026-05-01.
- [x] Confirm Cosmos compose mounts `/var/run/cosmos-docker.sock:/var/run/docker.sock` and not the host Docker socket directly — evidence: `cosmos-compose.yml.j2` volume review, 2026-05-01.
- [x] Confirm `homeos config cosmos on/off/status` manages or reports the shim service state coherently — evidence: CLI starts/stops shim with stack and status prints both units, 2026-05-01.
- [x] Confirm `homeos status` includes shim uptime/health or a clear shim status line — evidence: `cmd_status` prints state/substate/active-since for `homeos-cosmos-docker-shim.service`, 2026-05-01.

### Documentation and release

- [x] Update `docs/AI-GATE.md` from v0.4 bypass-warn log tailing to v0.5 proactive socket shim semantics — evidence: socket shim command/body semantics documented, 2026-05-01.
- [x] Update `docs/DAY2.md` with `homeos audit cosmos-events` and shim status expectations — evidence: CLI status and cosmos-events text reviewed/updated, 2026-05-01.
- [x] Update README feature summary for Cosmos Docker socket shim audit visibility — evidence: README mentions shim socket and `cosmos:<verb>:<resource>` / `BYPASS` audit entries, 2026-05-01.
- [x] Create or finalize `release-notes/v0.5.0.md` with user-facing summary and validation notes — evidence: release notes updated for command format, body redaction, static/harness validation, 2026-05-01.
- [x] Ensure no stale references claim v0.5 is future work once release finalization is complete — evidence: current docs plus legacy `PROJECT-INFO.md`/`HANDOFF.md` updated to describe v0.5 shim as present release scope and point v0.5-v0.9 policy to this roadmap, 2026-05-01.
- [x] Static validation passes: shell syntax, YAML parsing, targeted shim harness if available — evidence: `bash -n`, PyYAML parse, `python3 -m py_compile`, and local Unix-socket harness passed, 2026-05-01.
- [x] Orchestrator: commit, tag `v0.5.0`, push, publish release, and watch CI. No worker does this — evidence: commit `992655f`, tag/release `v0.5.0`, CI run `25235932085` passed and attached artifacts, 2026-05-01.

## v0.6.0 — Audit replay and sidecar payloads

Goal: implement root-only replay payload sidecars and CLI commands to show/replay prior audited intents through the AI gate.

### Audit data model

- [x] Extend `audit_log()` so mutating CLI commands write redacted JSONL entries as before and also write a root-only sidecar payload under `/var/lib/homeos/audit-replay/<diff_hash>.json` — evidence: `audit_log()` writes `sidecar_id`, temp harness verified public JSONL plus sidecar, 2026-05-01.
- [x] Sidecar files are mode `0600`, root-owned, and directory is root-only enough to protect secret-bearing replay material — evidence: Ansible creates `/var/lib/homeos/audit-replay` as root `0700`, writer chmods sidecars `0600`, gated mutators require root/fail closed on audit write failure, harness verified modes, 2026-05-01.
- [x] Sidecar payload includes original command intent, original argv, replay-safe environment needed for the command, timestamp, user, diff hash, and redaction metadata — evidence: sidecar schema `homeos.audit-replay.v1` includes these fields, 2026-05-01.
- [x] Sidecar payload does not accidentally expose secret values in the public JSONL audit line — evidence: `secrets:set` harness checked secret value absent from public JSONL before/after replay, 2026-05-01.
- [x] Define how duplicate `diff_hash` values are handled safely, either by including a unique suffix in sidecar storage or by proving hash collision risk is acceptable for this CLI scope — evidence: duplicate sidecars get unique suffixed `sidecar_id`; ambiguous bare hashes refuse with line-number guidance, 2026-05-01.

### CLI commands

- [x] Implement `homeos audit show <id_or_hash>` — evidence: `cmd_audit show` added and temp harness exercised line ID lookup, 2026-05-01.
- [x] `audit show` resolves line-number IDs and diff hashes — evidence: resolver supports line IDs plus numeric/non-numeric `diff_hash`/`sidecar_id`, ambiguity path tested, 2026-05-01.
- [x] `audit show` prints the public JSONL entry for all users allowed to read audit logs — evidence: temp harness output included raw public `audit[1]` JSONL, 2026-05-01.
- [x] `audit show` reveals sidecar payload only for root; non-root gets a clear refusal for sidecar content — evidence: non-root harness saw `sidecar: root-only`; root path gates on `id -u`, 2026-05-01.
- [x] Implement `homeos audit replay <id_or_hash>` — evidence: `cmd_audit replay` added and temp harness replayed `secrets:set`, 2026-05-01.
- [x] `audit replay` resolves line-number IDs and diff hashes to sidecar files — evidence: shared resolver maps numeric IDs and unique hashes to `sidecar_id` paths, 2026-05-01.
- [x] `audit replay` refuses with a clear error if the sidecar is missing or pruned — evidence: replay checks sidecar existence/readability and reports missing/pruned path, 2026-05-01.
- [x] `audit replay` reruns the original intent through the gate, so the reviewer sees it again — evidence: replay re-execs stored argv with `HOMEOS_NO_REVIEW` unset and original gate intent preserved, 2026-05-01.
- [x] `audit replay` writes a new audit entry with `cmd: "audit:replay:<orig_cmd>"` — evidence: temp harness verified `audit:replay:secrets:set:TEST_SECRET` JSONL entry, 2026-05-01.
- [x] Confirm replay works for `secrets:set` without leaking secret values into the public JSONL line — evidence: temp harness replayed `TEST_SECRET=supersecret` and grepped public JSONL for absence of the value, 2026-05-01.

### Retention and pruning

- [x] Add `homeos-audit-prune.service` to prune sidecars older than 90 days — evidence: Ansible installs systemd service running `/usr/local/sbin/homeos-audit-prune`, 2026-05-01.
- [x] Add `homeos-audit-prune.timer` and enable it from the appropriate Ansible role — evidence: `homeos-cli` role installs/enables daily persistent timer with daemon reload, 2026-05-01.
- [x] Prune implementation is safe if `/var/lib/homeos/audit-replay` is missing or empty — evidence: helper exits 0 when directory is absent; harness exercised missing directory, 2026-05-01.
- [x] Document that JSONL audit retention remains 10 years while replay sidecars retain 90 days — evidence: `docs/AI-GATE.md`, `docs/DAY2.md`, README, and v0.6.0 notes updated, 2026-05-01.

### Completion and docs

- [x] Update `docs/AI-GATE.md` with replay flow, root-only show behavior, retention, and examples — evidence: replay/show section and retention text added, 2026-05-01.
- [x] Update `docs/DAY2.md` CLI reference for `audit show` and `audit replay` — evidence: `homeos audit` reference added, 2026-05-01.
- [x] Update completions for bash and zsh — evidence: `show` and `replay` added to bash/zsh audit completions, 2026-05-01.
- [x] Create `release-notes/v0.6.0.md` — evidence: release notes file added with scope, retention, secret handling, and validation notes, 2026-05-01.
- [x] Static validation passes: shell syntax, YAML parsing, targeted audit/replay harness with temp paths — evidence: `bash -n`, PyYAML parse, audit_log sidecar harness, non-root mutator refusal, numeric-hash resolution, and prune harness passed without QEMU, 2026-05-01.
- [ ] Orchestrator: commit, tag `v0.6.0`, push, publish release, and watch CI. No worker does this.

## v0.7.0 — Bootstrap fixes

Goal: fix installer/bootstrap reliability issues discovered so far and make the first-boot system internally consistent without running VM boots in worker tasks.

### Debian installer and account setup

- [ ] Confirm preseed uses a non-reserved temporary installer username and renames it to `admin` in `late_command`.
- [ ] Confirm `/home/admin`, group ownership, sudoers, SSH authorized keys, and password expiry all survive the rename.
- [ ] Confirm public ISO mode still works with default password `homeos` expired on first login.
- [ ] Confirm private ISO mode still bakes `secrets/authorized_keys` without requiring that file to exist.
- [ ] Confirm `homeos secure` behavior matches docs and does not lock out key-based access.
- [ ] Improve `homeos secure` to prove or at least safely validate key-login readiness before disabling password auth, if feasible without VM/QEMU.

### Firstboot and Ansible reliability

- [ ] Verify `homeos-firstboot.service` ordering, logging, idempotence, and self-disable behavior from source.
- [ ] Verify `bootstrap/install.yml` role order remains coherent after v0.5/v0.6 changes.
- [ ] Ensure missing optional hardware such as `/dev/dri` does not fail bootstrap fatally.
- [ ] Ensure missing second disk `/dev/sdb` does not fail install or firstboot.
- [ ] Ensure network wait behavior is clear and bounded.
- [ ] Ensure firstboot creates `/var/lib/homeos/bootstrapped` only after success.
- [ ] Review roles for shell commands that should be modules or guarded idempotently.

### CLI/docs drift fixes

- [ ] Reconcile docs with actual `homeos` CLI commands for secrets, stack, net, backup, portal, cosmos, and audit.
- [ ] Either implement documented commands or remove them from docs; do not leave future-command claims in user docs.
- [ ] Ensure bash and zsh completions match actual CLI surface.
- [ ] Update `docs/TROUBLESHOOTING.md` for reserved username and bootstrap diagnostics.
- [ ] Create `release-notes/v0.7.0.md`.

### Completion checks

- [ ] Static validation passes: shell syntax, YAML parsing, Ansible syntax check if installed.
- [ ] Add any static smoke scripts needed for future orchestrator-run QEMU, but do not run QEMU.
- [ ] Orchestrator: commit, tag `v0.7.0`, push, publish release, and watch CI. No worker does this.

## v0.8.0 — Security, supply-chain, docs, and CI hardening

Goal: harden the project enough to become a release candidate after v0.9 polish.

### Security hardening

- [ ] Review Docker socket exposure after Cosmos shim; document residual risk and ensure Cosmos no longer receives the host socket directly.
- [ ] Review privileged containers and host mounts across all compose stacks.
- [ ] Review use of `latest` image tags; pin or explicitly document accepted latest-tag risks.
- [ ] Review `curl | sh` installer paths and add checksum/signature verification where practical.
- [ ] Review secret handling in CLI, audit log, replay sidecars, installers, docs, and shell environment files.
- [ ] Confirm audit logs and replay sidecars have appropriate permissions and retention behavior.
- [ ] Confirm no AI attribution footers or generated-by markers exist in commits, release notes, docs, or source.

### Supply-chain and reproducibility

- [ ] Record Debian base ISO checksum source and actual checksum in a reproducible location.
- [ ] Ensure `make pin-tools` updates all GitHub tool SHAs deterministically.
- [ ] Add or document builder image provenance and expected tool versions.
- [ ] Ensure release artifacts include ISO SHA256 files.
- [ ] Ensure release notes mention artifact verification.
- [ ] Review `.github/workflows/build-iso.yml` for tag/manual-only trigger policy; do not add push/PR triggers beyond tag matching.

### Docs and CI hardening

- [ ] Update README to reflect v0.8 feature/security state.
- [ ] Update `docs/SECURITY.md` threat model with Cosmos shim, audit replay, and accepted risks.
- [ ] Update `docs/ARCHITECTURE.md` with v0.6/v0.7/v0.8 reality.
- [ ] Update `docs/INSTALL-OPTIONALS.md` to match actual installer set.
- [ ] Ensure no `TODO`, `FIXME`, or `XXX` strings remain outside this roadmap where prohibited by handoff policy.
- [ ] Add CI/static checks that do not violate manual/tag-only workflow policy.
- [ ] Create `release-notes/v0.8.0.md`.

### Completion checks

- [ ] Static validation passes: shell syntax, YAML parsing, Ansible syntax check if installed, workflow YAML parse.
- [ ] Orchestrator: commit, tag `v0.8.0`, push, publish release, and watch CI. No worker does this.

## v0.9.0 — Release-candidate polish

Goal: make v0.9 the last feature/hardening milestone before v1.0 final full QEMU validation.

### Repository and docs polish

- [ ] Audit all docs for stale roadmap language, especially references to v0.4/v0.5/v0.6 as future work.
- [ ] Confirm README, `docs/AI-GATE.md`, `docs/DAY2.md`, `docs/INSTALL.md`, `docs/SECURITY.md`, and `docs/TROUBLESHOOTING.md` agree on current behavior.
- [ ] Confirm `docs/INSTALL-OPTIONALS.md` matches actual `bootstrap/installers/*.sh`.
- [ ] Confirm release notes exist for v0.5, v0.6, v0.7, v0.8, and v0.9.
- [ ] Confirm HANDOFF-LOG has one clear line per release with SHA and local ISO hash when available.
- [ ] Confirm there are no source/doc marker strings outside this roadmap that violate the no-inline-marker policy.

### Static release-candidate validation

- [ ] Run all shell syntax checks for `build/*.sh`, installer scripts, role files, and the `homeos` CLI.
- [ ] Run YAML parse checks for Ansible roles, vars, workflows, and docs metadata if any.
- [ ] Run `ansible-playbook --syntax-check bootstrap/install.yml` if Ansible is installed; otherwise record why skipped.
- [ ] Run targeted harnesses for audit replay and Cosmos shim without QEMU.
- [ ] Orchestrator-controlled: verify `make iso` builds locally when Docker is available; workers may propose this check but must not run it unless explicitly assigned.
- [ ] Verify GitHub Actions build artifacts attach to release on tag.

### v1.0 readiness package

- [ ] Create `release-notes/v0.9.0.md` with RC scope and known limitations.
- [ ] Create or update a v1.0 final validation checklist that the orchestrator can run later.
- [ ] Ensure v1.0 checklist explicitly includes the full QEMU/final full ISO validation that is deferred until v1.0.
- [ ] Orchestrator: commit, tag `v0.9.0`, push, publish release, and watch CI. No worker does this.

## v1.0.0 — Final full ISO validation only

This milestone exists for context and must not be executed by workers before the orchestrator starts v1.0.

- [ ] Orchestrator only: build final ISO.
- [ ] Orchestrator only: run full fresh QEMU install.
- [ ] Orchestrator only: verify SSH, firstboot/bootstrap completion, `homeos doctor`, audit/gate, installer dispatch, secure mode, reboot, and core services.
- [ ] Orchestrator only: run post-release CI ISO validation.
- [ ] Orchestrator only: tag/publish v1.0.0 when all validation passes.
