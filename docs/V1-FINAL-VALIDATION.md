# HomeOS v1.0 final validation checklist

Full QEMU and final ISO validation is deferred until v1.0. Do not run this checklist during v0.9 unless the orchestrator explicitly starts v1.0 validation.

## Preconditions

- v0.9.0 is tagged, released, and its GitHub Actions ISO build passed.
- Working tree has no unrelated product changes.
- The user can watch the QEMU session in a visible terminal, tmux pane, or interactive overlay.
- Test logs are written under `test/run/v1-final/`.

## Build

- Build the final amd64 ISO from committed pins.
- Record the ISO SHA256 in `HANDOFF-LOG.md`.
- Generate a fresh test SSH key and write only its public key to `secrets/authorized_keys` for the test ISO.

## Visible QEMU run

- Boot the ISO in QEMU with two disks and forwarded SSH.
- Keep serial output visible and tee it to `test/run/v1-final/qemu.log`.
- If acceleration fails, retry without acceleration and record the fallback.

## Pass criteria

- ISO boots without interactive installer prompts.
- Unattended Debian install completes.
- SSH works with the generated test key.
- `/var/lib/homeos/bootstrapped` exists.
- `homeos doctor` passes, or only documented virtual-hardware limitations fail and are recorded.
- A mutating `homeos` command writes an audit entry.
- `homeos audit show` and `homeos audit replay` work for a replayable entry.
- Installer dispatch records its installed flag.
- `homeos secure` does not lock out the active SSH key.
- Reboot succeeds and SSH returns.
- Required services and containers are healthy after reboot.
- Cosmos shim status and Cosmos-origin audit visibility are checked when Cosmos is enabled.

## Failure handling

- Do not tag v1.0 on failure.
- Preserve `test/run/v1-final/qemu.log` and any SSH-collected logs.
- Capture `homeos-firstboot`, bootstrap log tail, and `systemctl --failed` if SSH comes up.
- Summarize the blocker and fix plan before retrying.

See `V1-QEMU-TESTING-PROMPT.md` for the command-oriented runbook.
