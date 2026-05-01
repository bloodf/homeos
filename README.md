# HomeOS

Custom Debian 13.4 (Trixie) headless server ISO. Flash, boot, walk away.

End state after install: SSH-only box running Docker, CasaOS, Home Assistant,
Jellyfin (Intel QSV), Cockpit-managed NAS for USB drives, Caddy + Tailscale,
Vaultwarden, Watchtower, Restic backups, Node 24 LTS, Homebrew, and every
major AI coding CLI (Claude Code, Codex, Gemini, Cursor Agent, OpenCode, Kimi).

## Quick start

```bash
# 1. drop your SSH pubkey
cp ~/.ssh/id_ed25519.pub secrets/authorized_keys

# 2. build the ISO (uses Docker)
make iso

# 3. test in QEMU before flashing real hardware
make qemu-test

# 4. flash to USB
sudo dd if=dist/homeos-debian-13.4-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

## Day-2 ops

After first boot, SSH in and use the `homeos` CLI:

```
homeos status                      # services, disks, containers, GPU
homeos doctor                      # full smoke test
homeos config net tailscale-up     # join your tailnet
homeos config nas add /dev/sdc1    # mount + share a USB drive
homeos config secrets set ANTHROPIC_API_KEY=sk-ant-...
homeos config stack up jellyfin
homeos config rerun-bootstrap      # re-run Ansible roles
```

## Layout

See `plan` in `~/.claude/plans/im-building-a-home-cryptic-blum.md`.
