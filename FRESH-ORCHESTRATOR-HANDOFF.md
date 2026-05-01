# Fresh Orchestrator Agent Handoff

You are the fresh orchestrator agent for HomeOS.

Repo:

- Path: `/Users/heitor/Developer/github.com/bloodf/homeos`
- Origin: `https://github.com/bloodf/homeos`
- Current HEAD at handoff: `35e10c8`
- Latest pushed/released tag: `v0.4.0`
- Existing tags: `v0.1.0`, `v0.2.0`, `v0.3.0`, `v0.4.0`
- v0.5 implementation is committed locally in history, but `v0.5.0` is not tagged/released yet.
- Current known unrelated dirty local state may include `.omc/`, `.claude/`, `.pi/`, `.pi-lens/`; ignore/exclude those unless user explicitly asks.

Important policy update:

- `ROADMAP-TO-0.9.md` supersedes old `HANDOFF.md` QEMU requirements for v0.5-v0.9.
- v0.7 is now **bootstrap fixes**.
- v1.0 is **final full QEMU / full ISO validation only**.
- No worker/subagent may run QEMU before v1.0.
- Workers/subagents must not run:
  - `qemu-system-*`
  - `make qemu-test`
  - full VM boots
  - final ISO smoke
- The orchestrator owns:
  - git commits
  - tags
  - pushes
  - GitHub releases
  - ISO build approval
  - final v1.0 visible QEMU validation

Core files:

- `ROADMAP-TO-0.9.md` — authoritative roadmap/checklist.
- `SUBAGENT-PROMPTS-TO-0.9.md` — ready-to-copy worker/reviewer prompts.
- `HANDOFF.md` — historical/background only; do not follow its per-tag QEMU requirement for v0.5-v0.9.
- `HANDOFF-LOG.md` — append timestamped progress/release evidence.
- `release-notes/v0.5.0.md` exists.
- `release-notes/v0.6.0.md+` still need to be created as milestones land.

Workflow:

1. You are the orchestrator. Use subagents for implementation/review.
2. Workers may edit files but must not commit/tag/push/release.
3. Workers must update `ROADMAP-TO-0.9.md` checklist items they complete from `[ ]` to `[x]`, with short evidence/date.
4. Workers must not add inline work-marker strings in source/docs. Incomplete work belongs in `ROADMAP-TO-0.9.md`.
5. Use reviewers after worker changes.
6. You alone stage/commit/tag/release after review passes.
7. Keep commits atomic and conventional.
8. Never add AI attribution footers or co-author lines.

Current milestone status:

- v0.4.0: released.
- v0.5.0: Cosmos Docker socket shim implemented and reviewed, but not yet tagged/released.
  - Need final orchestrator verification from static checks/review, then commit any roadmap checkbox updates if needed, tag, release, watch CI.
- v0.6.0: audit replay not implemented.
- v0.7.0: bootstrap fixes not implemented.
- v0.8.0: security/supply-chain/docs/CI hardening not implemented.
- v0.9.0: release candidate polish not implemented.
- v1.0.0: final visible full QEMU validation only, done after v0.9.

Immediate next steps:

1. Read:
   - `ROADMAP-TO-0.9.md`
   - `SUBAGENT-PROMPTS-TO-0.9.md`
   - `HANDOFF-LOG.md`
   - `git status --short`
2. Start with v0.5 release finalization.
3. Use the v0.5 prompts from `SUBAGENT-PROMPTS-TO-0.9.md`.
4. Ensure workers mark v0.5 checklist items in `ROADMAP-TO-0.9.md`.
5. Review diff.
6. You commit/tag/release `v0.5.0`.
7. Repeat for v0.6, v0.7, v0.8, v0.9.
8. Do not run QEMU until v1.0 testing prompt is explicitly invoked by user.

Validation before each pre-v1.0 release:

- Static shell checks: `bash -n ...`
- Python compile where relevant: `python3 -m py_compile ...`
- YAML parse / `yamllint` if available
- `ansible-playbook --syntax-check bootstrap/install.yml` if installed; otherwise log skipped reason
- Targeted local harnesses only
- No QEMU
- No ISO full smoke unless orchestrator explicitly approves a build-only check; still no VM boot.

Release ritual for v0.5-v0.9:

1. Confirm clean product tree, excluding local tool state.
2. Run static/targeted validation.
3. Update release notes.
4. Update `HANDOFF-LOG.md`.
5. Commit.
6. Tag annotated release.
7. Push main/tag.
8. Create/update GitHub release.
9. Watch CI build.
10. Record result in `HANDOFF-LOG.md`.

Remember:

- The goal is to reach v0.9 with code/docs/release process ready.
- v1.0 is reserved for the visible final QEMU validation and release.
