#!/usr/bin/env bash
# ComfyUI image gen — GPU only.
set -euo pipefail
echo "== image-gen (ComfyUI) =="

if ! command -v nvidia-smi >/dev/null; then
  echo "no NVIDIA GPU detected — refusing CPU-only ComfyUI"
  echo "if you have an NVIDIA card: install nvidia-driver + nvidia-container-toolkit, reboot, retry"
  exit 1
fi

mkdir -p /srv/comfyui /opt/stacks/comfyui
cat >/opt/stacks/comfyui/docker-compose.yml <<'YML'
---
services:
  comfyui:
    image: yanwk/comfyui-boot:cu124-slim
    container_name: comfyui
    restart: unless-stopped
    ports: ["127.0.0.1:8188:8188"]
    volumes:
      - /srv/comfyui:/root
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
YML

(cd /opt/stacks/comfyui && docker compose up -d)

cat >/etc/caddy/conf.d/comfyui.caddy <<'CADDY'
@comfy host comfy.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @comfy { reverse_proxy localhost:8188 }
CADDY
systemctl reload caddy 2>/dev/null || true

echo "ComfyUI up at https://comfy.<tailnet>.ts.net"
echo "first launch downloads base SDXL — give it 10 min"
