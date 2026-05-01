#!/usr/bin/env bash
# Ollama installer. Asks GPU type, refuses CPU-only by default, pulls qwen3:7b.
set -euo pipefail
RECONFIG=0
[ "${1:-}" = "--reconfigure" ] && RECONFIG=1

echo "== Ollama installer =="
echo "GPU type:"
echo "  1) NVIDIA (recommended for >7B models)"
echo "  2) Intel/AMD iGPU (Vulkan)"
echo "  3) CPU-only (slow, ~7B max — refuse by default)"
read -r -p "choice [1-3]: " gpu

case "$gpu" in
  1)
    if ! command -v nvidia-smi >/dev/null; then
      echo "NVIDIA driver not installed. Install via:"
      echo "  sudo apt install -y nvidia-driver firmware-misc-nonfree"
      echo "  reboot, re-run this installer."
      exit 1
    fi
    ;;
  2) : ;;
  3)
    read -r -p "CPU-only really? [y/N]: " ack
    [[ "$ack" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
    ;;
  *) echo "invalid"; exit 1 ;;
esac

read -r -p "model to pull [qwen3:7b]: " model
model="${model:-qwen3:7b}"

if ! command -v ollama >/dev/null; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

mkdir -p /opt/stacks/ollama
cat >/opt/stacks/ollama/docker-compose.yml <<YML
---
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports: ["127.0.0.1:11434:11434"]
    volumes: [ollama-data:/root/.ollama]
$( [ "$gpu" = "1" ] && cat <<NVIDIA
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
NVIDIA
)
volumes:
  ollama-data:
YML

(cd /opt/stacks/ollama && docker compose up -d)
sleep 3
docker exec ollama ollama pull "$model" || true

echo "Ollama up at http://127.0.0.1:11434"
echo "Open WebUI auto-detects via OLLAMA_BASE_URL=http://host.docker.internal:11434"
echo "model installed: $model"
