#!/usr/bin/env bash
# Whisper + Piper for HA Voice Assist.
set -euo pipefail
echo "== voice (Whisper + Piper) =="

mkdir -p /srv/voice/{whisper,piper} /opt/stacks/voice

read -r -p "Whisper model [small-int8]: " wmodel
wmodel="${wmodel:-small-int8}"
read -r -p "Piper voice [en_US-amy-medium]: " pvoice
pvoice="${pvoice:-en_US-amy-medium}"

cat >/opt/stacks/voice/docker-compose.yml <<YML
---
services:
  whisper:
    image: rhasspy/wyoming-whisper:latest
    container_name: whisper
    restart: unless-stopped
    command: --model ${wmodel} --language en
    ports: ["127.0.0.1:10300:10300"]
    volumes: [/srv/voice/whisper:/data]
  piper:
    image: rhasspy/wyoming-piper:latest
    container_name: piper
    restart: unless-stopped
    command: --voice ${pvoice}
    ports: ["127.0.0.1:10200:10200"]
    volumes: [/srv/voice/piper:/data]
YML

(cd /opt/stacks/voice && docker compose up -d)

echo "Whisper (STT) at tcp://127.0.0.1:10300"
echo "Piper   (TTS) at tcp://127.0.0.1:10200"
echo "Add as Wyoming integrations in Home Assistant: Settings → Integrations → Wyoming Protocol"
