2026-05-01T18:00:57Z — handoff received, HEAD=36dfc67
2026-05-01T18:01:36Z — plan HEAD=36dfc67: [ ] verify carryover #6-#12; [ ] implement v0.4 Cosmos bypass audit reader + CLI; [ ] update docs; [ ] run static checks; [ ] commit v0.4 implementation; [ ] build/smoke/tag if environment permits.
2026-05-01T18:02:04Z — carryover #6 CLOSED by 7601692: preseed uses admin/homeos + chage -d 0; repack creates empty authorized_keys when absent; Makefile warns only.
2026-05-01T18:02:04Z — carryover #7 PARTIAL: homeos secure validates authorized_keys and locks password, but source does not prove live SSH key login before flipping PasswordAuthentication.
2026-05-01T18:02:04Z — carryover #8 CLOSED by 7601692: bootstrap/roles/ssh/tasks/main.yml sets PasswordAuthentication yes initially.
2026-05-01T18:02:04Z — carryover #9 CLOSED by 7601692: firewall_allow_tcp/firewall_allow_udp exist with NFS UDP, Samba UDP, mDNS.
2026-05-01T18:02:04Z — carryover #10 CLOSED by 7601692: Makefile pin-tools runs build/refresh-pins.sh --write; refresh-pins rewrites bootstrap/vars/main.yml.
2026-05-01T18:02:04Z — carryover #11 CLOSED locally: Makefile has builder/base-iso/iso targets; dist/homeos-debian-13.4-amd64.iso sha256=430286eda6cec02c56264b4e8ceb15e6d8bc4dea84bd1a2fd0b3401c143cb52a.
2026-05-01T18:02:04Z — carryover #12 OPEN: no QEMU PASS entry found in HANDOFF-LOG.md; must run full smoke before tag.
2026-05-01T18:02:04Z — plan updated: [x] verify carryover #6-#12; [ ] implement v0.4 Cosmos bypass audit reader + CLI; [ ] update docs; [ ] run static checks; [ ] commit v0.4 implementation; [ ] build/smoke/tag if environment permits.
2026-05-01T18:05:28Z — plan updated: [x] verify carryover #6-#12; [x] implement v0.4 Cosmos bypass audit reader + CLI; [x] update docs; [x] run static checks (bash -n, yaml parse, CLI temp audit test, Cosmos audit fake-docker test; ansible syntax skipped: ansible-playbook not installed); [ ] commit v0.4 implementation; [ ] build/smoke/tag if environment permits.
2026-05-01T18:06:08Z — commit d109170 feat(cosmos): mirror UI actions to audit log; v0.4 implementation static checks passed except ansible syntax unavailable locally.
2026-05-01T18:06:08Z — plan updated: [x] verify carryover #6-#12; [x] implement v0.4 Cosmos bypass audit reader + CLI; [x] update docs; [x] run static checks; [x] commit v0.4 implementation; [ ] build/smoke/tag if environment permits.
TEST_HOSTNAME=homeos-test-19373 TEST_FAKE_KEY=<redacted fake test key>
01d70b71dfb3fe5684103cb625a203969a4920ddb58867dea3cfe3c99345d024 dist/homeos-debian-13.4-amd64.iso
2026-05-01T18:38:50Z — QEMU smoke attempt failed before boot: /opt/homebrew/bin/qemu-system-x86_64 reports invalid accelerator hvf; retrying without acceleration.
2026-05-01T19:41:02Z — QEMU smoke failed in Debian installer before SSH: username admin is reserved by d-i user-setup; fixed preseed to skip d-i user creation and create admin in late_command.
2026-05-01T19:45:00Z — rebuilt smoke ISO after preseed admin-user fix sha256=f301a7cd74726760b2388f6e6503ca1f0ba88404ad2ac832dabb4f5915822048
2026-05-01T20:20:00Z — parallel agents completed: researcher recommended temp diadmin + late rename; reviewer flagged unclean tree and no successful smoke; planner supplied light QEMU smoke protocol per user scope.
2026-05-01T20:20:00Z — preseed fix revised: use supported d-i first-user flow with temporary diadmin and rename to admin in late_command; static bash/yaml checks passed.
2026-05-01T20:24:40Z — refreshed GitHub tool pins during smoke ISO build: hindsight=4986e8ec370a29dff5379de5dd9a014840fda9c1.
2026-05-01T20:25:00Z — rebuilt smoke ISO after temp-user preseed fix sha256=33b607de0cf23dd1e9936fdce5b4a528571a8226d9ea8e4a7738ac9f470efd06
2026-05-01T20:29:00Z — LIGHT QEMU smoke PASS commit=b4324d2 iso=33b607de0cf23dd1e9936fdce5b4a528571a8226d9ea8e4a7738ac9f470efd06; pass scope per user: ISO boots and unattended d-i reaches install path (base/apt component stage), not full bootstrap/services.
2026-05-01T20:30:05Z — RELEASE v0.4.0 sha=9c17903 iso=33b607de0cf23dd1e9936fdce5b4a528571a8226d9ea8e4a7738ac9f470efd06; GitHub release published; QEMU scope light per user instruction.
2026-05-01T21:50:00Z — created ROADMAP-TO-0.9.md and SUBAGENT-PROMPTS-TO-0.9.md planning artifacts for v0.5-v0.9 parallel agent work; no product implementation.
2026-05-01T21:52:58Z — review fixes applied to planning artifacts: ROADMAP/SUBAGENT prompts now explicitly supersede HANDOFF QEMU/full-smoke for v0.5-v0.9 workers, add parallel-edit coordination, avoid prompt marker noise, and clarify orchestrator-controlled ISO/QEMU validation.
2026-05-01T22:01:02Z — created FRESH-ORCHESTRATOR-HANDOFF.md and V1-QEMU-TESTING-PROMPT.md prompt files for fresh orchestrator and visible v1.0 QEMU testing.
2026-05-01T22:26:50Z — v0.5.0 finalization validated in worktree chore/v0.5-finalize: bash -n homeos/completion passed; shim compile and local Unix-socket harness passed; YAML parse passed; ansible syntax skipped (ansible-playbook unavailable); QEMU not run per ROADMAP-TO-0.9 policy.
2026-05-01T22:32:20Z — RELEASE v0.5.0 sha=992655f; GitHub release published; CI build run 25235932085 passed for amd64/arm64 and attached release artifacts; QEMU not run per v0.5-v0.9 roadmap policy.
2026-05-01T22:59:30Z — RELEASE v0.6.0 sha=9da8b87; GitHub release published; CI build run 25236717937 passed for amd64/arm64 and attached release artifacts; QEMU not run per v0.5-v0.9 roadmap policy.
2026-05-01T23:24:00Z — RELEASE v0.7.0 sha=75b7168; GitHub release published; CI build run 25237384242 passed for amd64/arm64 and attached release artifacts; QEMU not run per v0.5-v0.9 roadmap policy.
2026-05-02T00:06:30Z — RELEASE v0.8.0 sha=af958b0; GitHub release published https://github.com/bloodf/homeos/releases/tag/v0.8.0; CI build run 25238338081 passed for amd64/arm64 and attached release artifacts; QEMU not run per v0.5-v0.9 roadmap policy.
2026-05-02T00:21:30Z — RELEASE v0.9.0 sha=df593f7; GitHub release published https://github.com/bloodf/homeos/releases/tag/v0.9.0; CI build run 25238707065 passed for amd64/arm64 and attached release artifacts; QEMU not run per v0.5-v0.9 roadmap policy.
2026-05-02T01:34:00Z — RELEASE v0.9.5 sha=1ae0e2c; GitHub release published https://github.com/bloodf/homeos/releases/tag/v0.9.5; CI build run 25240414035 passed for amd64/arm64 and attached release artifacts; QEMU not run per v0.5-v0.9 roadmap policy.
--- v1 final validation start  ---
commit=b39718f
describe=v0.9.5-2-gb39718f-dirty
branch=main
status_start<<EOF
 M .omc/state/hud-state.json
 M .omc/state/hud-stdin-cache.json
 M HANDOFF-LOG.md
?? subagent-ideas-glm51.md
?? subagent-ideas-k2p6.md
?? subagent-ideas-m27.md
?? subagent-ideas-scout.md
EOF
--- v1 final validation prepared 2026-05-02T03:10:28-0300 ---
TEST_HOSTNAME=homeos-v1-final-19367 TEST_FAKE_KEY=sk-ant-test-3d8763cbd945698db683548e9666e46c
4e0d97c414bb7d33c31a1111fcf5e146c16dca038cc99383827b022b1700bef0  dist/homeos-debian-13.4-amd64.iso
--- v1 qemu attempt 1 failed 2026-05-02T03:19:03-0300 ---
FAIL: Debian installer stopped at Partition disks: No root file system. Root cause hypothesis: QEMU virtio disks are /dev/vda,/dev/vdb but preseed hardcoded /dev/sda,/dev/sdb.
198e9512cab9d5891247f9a763cb7e6687af5f07b228e7cec23365ff3618e43a  dist/homeos-debian-13.4-amd64.iso
--- v1 qemu attempt 2 rebuilt 2026-05-02T03:20:03-0300 ---
Fix: dynamic installer disk selection for OS and optional second disk.
--- v1 qemu attempt 2 failed 2026-05-02T04:04:25-0300 ---
FAIL: installer passed partitioning/grub, then hung in late_command lvcreate for optional vg1 swap/cache on /dev/vdb (wchan __do_semtimedop).
159d68fc1667b3b209f72b926a7973b0c28d8827a772e566f9ab963279f2627b  dist/homeos-debian-13.4-amd64.iso
--- v1 qemu attempt 3 rebuilt 2026-05-02T04:05:18-0300 ---
Fix: removed optional second-disk LVM creation from installer late_command; installer now only owns OS disk.
--- v1 qemu attempt 3 harness failure 2026-05-02T05:09:01-0300 ---
Installer completed and rebooted, but QEMU launch used '-boot d', so VM booted the CD again instead of installed disk. Fixing test harness to use first-boot-only CD boot.
--- v1 qemu attempt 4 failed 2026-05-02T09:38:57-0300 ---
FAIL: SSH was reachable, but baked-key login blocked by expired password; after manual password change bootstrap failed at Homebrew formulas because QEMU TCG default CPU lacked SSSE3.
Fixes: move public password expiry after successful bootstrap, create admin .config before shell config copy, set QEMU CPU to max in visible harness.
2522980a18a0f2800bec78a5d49ef52777afb44af0a16040517852de0ea4ce41  dist/homeos-debian-13.4-amd64.iso
--- v1 qemu attempt 5 rebuilt 2026-05-02T09:39:16-0300 ---
TEST_HOSTNAME=homeos-v1-final-25173 TEST_FAKE_KEY=sk-ant-test-1bac19112a29d198933984fb2851da20
ISO SHA256: 7b40bfb970a06a8c821f2dc4d1c64de5a8ee0445cfa23020da4cbc8841b695d9
TEST_HOSTNAME=homeos-v1-final-1394 TEST_FAKE_KEY=sk-ant-test-445df85bb2eb2b6f6293f2e90946664d
