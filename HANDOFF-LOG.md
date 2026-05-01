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
