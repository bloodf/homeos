# Subagent Prompt Pack to v0.9

Use these prompts from the orchestrator. They are ready to copy into worker or reviewer agents. Every prompt intentionally prohibits QEMU and git/release operations. These prompts and ROADMAP-TO-0.9.md supersede HANDOFF.md QEMU/full-smoke requirements for v0.5-v0.9 worker/subagent work; full QEMU/final ISO validation is v1.0 orchestrator-only.

## Global worker constraints to preserve in every task

- Do not commit, tag, push, publish releases, or edit git history.
- Do not run QEMU, `qemu-system-*`, `make qemu-test`, full VM boot, or any equivalent ISO boot. QEMU is deferred to v1.0 and orchestrator-only.
- Do not run `make iso` or equivalent ISO builds unless the orchestrator explicitly assigns that build task; otherwise propose the check to the orchestrator.
- Update `ROADMAP-TO-0.9.md` checkboxes for completed items with short evidence/date.
- Do not add inline unfinished-work marker strings in source/docs; leave incomplete work unchecked in `ROADMAP-TO-0.9.md`.
- In parallel runs, do not edit shared roadmap/docs/release notes unless your assigned scope gives you a non-overlapping section or worktree. If updating ROADMAP checkboxes, keep edits minimal and scoped to your assigned checklist section.
- Run static/targeted validation only.
- Report files changed and validation performed.

---

## v0.5 worker — release finalization for Cosmos Docker socket shim

```text
You are a worker subagent. Planning context is in ROADMAP-TO-0.9.md. Your scope is v0.5.0 only: finalize the Cosmos Docker socket shim release implementation. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Goal:
- Validate and minimally fix the existing v0.5 Cosmos Docker socket shim work so it is ready for orchestrator release.

Tasks:
- Read ROADMAP-TO-0.9.md v0.5.0 checklist, bootstrap/roles/cosmos, bootstrap/roles/homeos-cli/files/homeos, docs/AI-GATE.md, docs/DAY2.md, README.md, and release-notes/v0.5.0.md.
- Confirm Cosmos uses /var/run/cosmos-docker.sock rather than mounting host /var/run/docker.sock directly.
- Confirm shim service lifecycle is managed by Ansible and homeos CLI toggles/status.
- Confirm audit entries for mutating Docker API methods use the required cosmos command format, verdict BYPASS, and safe body hash/summary behavior.
- Make only narrow fixes needed for v0.5 release readiness.
- Update ROADMAP-TO-0.9.md checkboxes for completed v0.5 checklist item(s) with short evidence/date.

Validation:
- bash -n for changed shell scripts and homeos CLI.
- YAML parse for changed Ansible files.
- Targeted local shim harness is allowed only if it does not use QEMU/VM boot.
- Do not run QEMU.

Return:
- Files changed.
- ROADMAP items marked complete.
- Validation run and results.
- Remaining risks/questions.
```

## v0.5 reviewer — release readiness review

```text
You are a reviewer subagent. Review-only unless explicitly asked to apply tiny documentation/checklist fixes. Scope is v0.5.0 Cosmos Docker socket shim release readiness. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Inspect:
- ROADMAP-TO-0.9.md v0.5.0 section.
- Current diff and committed state around bootstrap/roles/cosmos, homeos CLI, docs, and release notes.

Findings requested:
- Correctness bugs in shim behavior, service lifecycle, compose socket mount, or audit entry shape.
- Stale v0.4 log-tail references.
- Docs/CLI drift.
- Missing static validation.
- Any ROADMAP checkbox marked complete without evidence.

Output:
- Critical/blocking findings first, each with file path and evidence.
- Non-blocking cleanup suggestions separately.
- Do not run QEMU.
- If you change any checklist/docs line, update ROADMAP-TO-0.9.md with evidence/date and report it.
```

---

## v0.6 worker — audit replay implementation

```text
You are a worker subagent. Scope is v0.6.0 audit replay implementation only. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Goal:
- Implement root-only audit replay sidecars and homeos audit show/replay commands per ROADMAP-TO-0.9.md v0.6.0.

Read first:
- ROADMAP-TO-0.9.md v0.6.0 checklist.
- bootstrap/roles/homeos-cli/files/homeos.
- bootstrap/roles/homeos-cli/tasks/main.yml.
- homeos CLI completions: bootstrap/roles/homeos-cli/files/homeos.bash-completion and bootstrap/roles/homeos-cli/files/_homeos.
- docs/AI-GATE.md and docs/DAY2.md.

Implementation requirements:
- Extend audit logging to write public redacted JSONL and root-only replay sidecars under /var/lib/homeos/audit-replay/.
- Implement homeos audit show <id_or_hash> and homeos audit replay <id_or_hash>.
- Replay must re-run through the gate and write a new audit entry using cmd audit:replay:<orig_cmd>.
- Add 90-day sidecar prune service/timer through Ansible.
- Update bash/zsh completions, docs, and release-notes/v0.6.0.md.
- Do not leak secret values into public JSONL.
- Update ROADMAP-TO-0.9.md completed v0.6 checkboxes with short evidence/date.

Validation:
- bash -n changed shell scripts.
- YAML parse changed Ansible files.
- Targeted temp-directory harness for audit show/replay and prune logic, without QEMU.
- Do not run QEMU.

Return:
- Files changed.
- ROADMAP items marked complete.
- Validation results.
- Any replay edge cases or risks.
```

## v0.6 reviewer — audit replay security/correctness review

```text
You are a reviewer subagent. Scope is v0.6 audit replay and sidecar security. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Review:
- homeos audit_log changes.
- sidecar file creation paths, permissions, and data contents.
- audit show/replay resolution of line IDs and hashes.
- replay gate behavior and new audit entry shape.
- prune timer/service.
- docs and completions.
- ROADMAP-TO-0.9.md v0.6 evidence on checked items.

Focus:
- Secret leakage into public JSONL.
- Root-only sidecar protection.
- Command injection or unsafe eval/replay behavior.
- Missing sidecar handling.
- Replay of stale/pruned entries.
- Validation quality.

Return:
- Blocking findings with file paths and evidence.
- Suggested smallest fixes.
- Non-blocking polish.
- Do not run QEMU.
```

---

## v0.7 worker — bootstrap fixes

```text
You are a worker subagent. Scope is v0.7.0 bootstrap fixes only. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Goal:
- Fix source-level installer/bootstrap reliability issues without VM booting. QEMU is deferred to v1.0 orchestrator-only.

Read first:
- ROADMAP-TO-0.9.md v0.7.0 checklist.
- preseed/preseed.cfg.
- bootstrap/files/homeos-firstboot.service.
- bootstrap/install.yml.
- bootstrap/roles/ssh, base, firstboot, homeos-cli, docker, gpu-intel, cosmos.
- docs/INSTALL.md, docs/BOOTSTRAP.md, docs/TROUBLESHOOTING.md, docs/DAY2.md.

Tasks:
- Verify/fix temp installer user to admin rename flow in preseed.
- Verify/fix SSH key copy, sudoers, password expiry, group ownership, public/private ISO behavior.
- Verify/fix firstboot ordering, logging, idempotence, and bootstrapped marker semantics.
- Ensure optional hardware/second disk/network conditions are guarded.
- Reconcile documented homeos commands with actual CLI or update implementation/docs narrowly.
- Create release-notes/v0.7.0.md.
- Update ROADMAP-TO-0.9.md completed v0.7 checkboxes with short evidence/date.

Validation:
- bash -n changed shell files.
- YAML parse changed Ansible files.
- ansible-playbook --syntax-check bootstrap/install.yml if available.
- Static grep/schema checks for preseed and docs/CLI drift.
- Do not run QEMU.

Return:
- Files changed.
- ROADMAP items marked complete.
- Validation results.
- Remaining bootstrap risks that require v1.0 QEMU.
```

## v0.7 reviewer — bootstrap reliability review

```text
You are a reviewer subagent. Scope is v0.7 bootstrap reliability. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Review:
- preseed account setup and late_command.
- firstboot service and role ordering.
- optional disk/GPU/network handling.
- homeos secure safety.
- docs/CLI drift fixes.
- ROADMAP-TO-0.9.md v0.7 checked-item evidence.

Return:
- Blocking issues likely to break unattended install/bootstrap, with file paths.
- Static-only validation gaps.
- Docs inconsistencies.
- Smallest safe fixes.
- Do not run QEMU.
```

---

## v0.8 worker — security/supply-chain/docs/CI hardening

```text
You are a worker subagent. Scope is v0.8.0 hardening only. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Goal:
- Harden security, supply-chain, docs, and CI policy enough for v0.9 release-candidate polish.

Read first:
- ROADMAP-TO-0.9.md v0.8.0 checklist.
- .github/workflows/build-iso.yml.
- Makefile, build/*.sh, bootstrap/vars/main.yml.
- docs/SECURITY.md, docs/ARCHITECTURE.md, docs/INSTALL-OPTIONALS.md, README.md.
- Docker compose templates and installer scripts.

Tasks:
- Review and fix/document Docker socket exposure, privileged containers, host mounts, latest image tags, curl installers, secret handling, audit permissions.
- Improve or document supply-chain provenance: Debian ISO checksum, GitHub tool pins, builder tooling, release artifact verification.
- Keep CI manual/tag-only. Do not add push/PR triggers beyond tag policy.
- Add static checks only if they fit policy.
- Update docs and create release-notes/v0.8.0.md.
- Update ROADMAP-TO-0.9.md completed v0.8 checkboxes with evidence/date.

Validation:
- bash -n relevant scripts.
- YAML parse workflows/Ansible.
- Static checks for forbidden marker strings outside ROADMAP-TO-0.9.md.
- Do not run QEMU.

Return:
- Files changed.
- ROADMAP items marked complete.
- Validation results.
- Residual accepted risks.
```

## v0.8 reviewer — hardening review

```text
You are a reviewer subagent. Scope is v0.8 security/supply-chain/docs/CI hardening. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Review:
- Docker/Cosmos socket exposure and privileged containers.
- Secret leakage risk in audit/replay/docs/scripts.
- GitHub workflow trigger policy and artifact handling.
- Supply-chain pinning/provenance.
- Docs consistency with implemented behavior.
- ROADMAP-TO-0.9.md v0.8 checked-item evidence.

Return:
- Blocking security/release risks first.
- Evidence-backed file references.
- Non-blocking improvements.
- Do not run QEMU.
```

---

## v0.9 worker — release-candidate polish

```text
You are a worker subagent. Scope is v0.9.0 release-candidate polish only. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Goal:
- Make the repo coherent and ready for orchestrator-only v1.0 final full QEMU validation.

Read first:
- ROADMAP-TO-0.9.md v0.9.0 checklist.
- README.md and all docs under docs/.
- release-notes/.
- bootstrap/installers and homeos CLI.
- Makefile and build scripts.

Tasks:
- Remove stale roadmap/future language from docs.
- Reconcile docs with actual CLI and installer set.
- Ensure release notes exist for v0.5-v0.9.
- Create or update the v1.0 final validation checklist referenced by ROADMAP-TO-0.9.md.
- Run static release-candidate validation only.
- Update ROADMAP-TO-0.9.md completed v0.9 checkboxes with evidence/date.

Validation:
- bash -n for scripts.
- YAML parse for Ansible/workflows.
- ansible syntax if installed.
- Targeted audit/Cosmos harnesses if useful and non-QEMU.
- ISO builds are orchestrator-controlled: propose `make iso` to the orchestrator when useful, but do not run it unless explicitly assigned; never run QEMU.

Return:
- Files changed.
- ROADMAP items marked complete.
- Validation results.
- Items that must wait for v1.0 full QEMU.
```

## v0.9 reviewer — RC readiness review

```text
You are a reviewer subagent. Scope is v0.9 release-candidate readiness. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Review:
- ROADMAP-TO-0.9.md v0.9 and v1.0 readiness checklist.
- README/docs/release notes consistency.
- CLI/completions/docs consistency.
- Static validation evidence.
- Marker policy: no inline unfinished-work marker strings outside ROADMAP-TO-0.9.md where prohibited.

Return:
- Release-blocking issues before v0.9 tag.
- Evidence-backed file paths.
- What can safely wait for v1.0 QEMU.
- Do not run QEMU.
```

---

## Generic parallel review prompt

```text
You are a reviewer subagent. Review the current diff for the assigned milestone only. Do not commit/tag/push. Do not run QEMU, qemu-system-*, make qemu-test, or any VM boot.

Check:
- Does the diff satisfy the relevant ROADMAP-TO-0.9.md checklist items?
- Are completed checkboxes marked with short evidence/date?
- Are docs and release notes updated?
- Are static validations appropriate and recorded?
- Are there correctness, security, idempotence, or maintainability regressions?

Return:
- Blocking findings with file paths and evidence.
- Non-blocking suggestions.
- Any unchecked roadmap items that must remain open.
```
