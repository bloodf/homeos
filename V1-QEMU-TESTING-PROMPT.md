# v1.0 Visible QEMU Testing Prompt

You are the v1.0 validation/testing agent for HomeOS.

Your job:
Run the final full visible QEMU / full ISO validation for v1.0. The user wants to SEE the test happening.

Repo:
- `/Users/heitor/Developer/github.com/bloodf/homeos`

Policy:
- This is the first point where full QEMU validation is allowed.
- Use a visible/supervised QEMU session, preferably via tmux or an interactive terminal/overlay.
- Do not hide the QEMU output in a silent background-only process.
- The user must be able to watch installer/bootstrap progress.
- You may use tmux panes/windows, `script`, or an interactive shell overlay.
- Record all logs and outcomes.

Before starting:
1. Confirm current git state:
   ```bash
   git status --short
   git rev-parse --short HEAD
   git describe --tags --always --dirty
   ```
2. Confirm v0.9 is tagged/released and current branch is the intended v1.0 candidate.
3. Confirm no unrelated product-file changes are pending.
4. Create test run dir:
   ```bash
   mkdir -p test/run/v1-final
   ```

Build final ISO:
```bash
make builder
make base-iso
make pin-tools
make iso
sha256sum dist/homeos-debian-13.4-amd64.iso | tee -a HANDOFF-LOG.md
```

Prepare visible QEMU test:
```bash
cd test/run/v1-final
ssh-keygen -t ed25519 -N '' -f id_test -C test@homeos
TEST_PUBKEY="$(cat id_test.pub)"
TEST_HOSTNAME="homeos-v1-final-$RANDOM"
TEST_FAKE_KEY="sk-ant-test-$(openssl rand -hex 16)"
echo "TEST_HOSTNAME=$TEST_HOSTNAME TEST_FAKE_KEY=$TEST_FAKE_KEY" >> ../../HANDOFF-LOG.md
cd ../..
echo "$TEST_PUBKEY" > secrets/authorized_keys
chmod 0644 secrets/authorized_keys
make iso
sha256sum dist/homeos-debian-13.4-amd64.iso | tee -a HANDOFF-LOG.md
```

Launch visible QEMU:
Preferred: use tmux so user can attach/watch.

```bash
cd test/run/v1-final
qemu-img create -f qcow2 disk1.qcow2 60G
qemu-img create -f qcow2 disk2.qcow2 20G

tmux new-session -d -s homeos-v1-qemu "
qemu-system-x86_64 \
  -name \"$TEST_HOSTNAME\" \
  -m 8192 -smp 4 \
  -cdrom ../../dist/homeos-debian-13.4-amd64.iso \
  -drive file=disk1.qcow2,if=virtio \
  -drive file=disk2.qcow2,if=virtio \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=n0 \
  -nographic -serial mon:stdio \
  -boot d 2>&1 | tee qemu.log
"
echo "User can watch with: tmux attach -t homeos-v1-qemu"
```

If host supports acceleration:
- Linux: add `-enable-kvm -cpu host`
- macOS if supported: add `-accel hvf`
- If acceleration fails, retry without acceleration and log it.

Verification steps:
Define SSH helper:
```bash
cd test/run/v1-final
SSH() {
  ssh -p 2222 -i id_test \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    admin@localhost "$@"
}
```

Stage A — installer completes and SSH comes up:
```bash
for i in $(seq 1 240); do
  SSH "echo ok" && break
  sleep 10
done || { echo "FAIL: SSH never came up"; exit 1; }
```

Stage B — bootstrap completes:
```bash
SSH 'until test -f /var/lib/homeos/bootstrapped; do
       sleep 30
       sudo tail -n 5 /var/log/homeos-bootstrap.log || true
     done'
```

Stage C — doctor:
```bash
SSH 'homeos doctor'
```
If `homeos doctor` reports GPU-only failures due QEMU lacking `/dev/dri`, record and classify whether acceptable per docs. Do not hide failures.

Stage D — audit/gate:
```bash
SSH 'sudo homeos config gate set none'
SSH "HOMEOS_AUTO_APPLY=1 sudo homeos config secrets set TEST_KEY=$TEST_FAKE_KEY"
SSH 'homeos audit tail -n 10 | grep -q secrets:set'
```

Stage E — audit replay if v0.6+:
```bash
SSH 'sudo homeos audit tail -n 20'
SSH 'sudo homeos audit show 1 || true'
```
If there is a replayable secrets entry:
```bash
SSH 'sudo homeos audit replay <id_or_hash>'
```
Use an actual replayable ID/hash discovered from audit output.

Stage F — installer dispatch:
```bash
SSH 'HOMEOS_AUTO_APPLY=1 sudo homeos install ai-keys --reconfigure </dev/null || true'
SSH 'test -f /var/lib/homeos/installed.d/ai-keys.installed'
```

Stage G — secure mode:
```bash
SSH 'sudo homeos secure'
SSH 'echo still-works'
```

Stage H — reboot and service health:
```bash
SSH 'sudo systemctl reboot' || true
sleep 90
for i in $(seq 1 60); do
  SSH 'systemctl is-system-running' && break || sleep 10
done

SSH 'systemctl is-active docker tailscaled cockpit.socket'
SSH 'docker ps --format "{{.Names}}" | sort' | tee containers.txt
```

Required containers:
```bash
for required in homeassistant vaultwarden watchtower; do
  grep -q "^$required" containers.txt || {
    echo "FAIL: missing $required"
    exit 1
  }
done
```

Cosmos shim validation if Cosmos enabled/installed:
```bash
SSH 'systemctl status homeos-cosmos-docker-shim.service --no-pager || true'
SSH 'homeos config cosmos status || true'
SSH 'homeos audit cosmos-events -n 20 || true'
```

Pass criteria:
- User can visibly watch QEMU/tmux session.
- ISO boots.
- Unattended install completes.
- SSH works with generated test key.
- `/var/lib/homeos/bootstrapped` exists.
- `homeos doctor` passes or only documented QEMU hardware limitations fail.
- Audit records mutating command.
- Installer dispatch records flag file.
- `homeos secure` does not lock us out.
- Reboot works.
- Required core services/containers are healthy.
- Logs are saved.

On pass, append:
```bash
echo "V1 FULL QEMU PASS commit=$(git rev-parse --short HEAD) iso=$(sha256sum dist/homeos-debian-13.4-amd64.iso | cut -d' ' -f1)" >> HANDOFF-LOG.md
```

On failure:
- Do not tag v1.0.
- Keep `test/run/v1-final/qemu.log`.
- Capture:
  ```bash
  tail -200 test/run/v1-final/qemu.log
  ```
- If SSH came up, capture:
  ```bash
  SSH 'sudo journalctl -u homeos-firstboot --no-pager -n 200 || true'
  SSH 'sudo tail -n 200 /var/log/homeos-bootstrap.log || true'
  SSH 'systemctl --failed || true'
  ```
- Summarize failure cause and next fix prompt.

Teardown only after user approves or logs are saved:
```bash
tmux kill-session -t homeos-v1-qemu 2>/dev/null || true
rm -f secrets/authorized_keys
```

Final rule:
Do not create v1.0 tag until the user has seen the QEMU run and the full validation passes.
