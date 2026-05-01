#!/usr/bin/env bash
# Sonarr/Radarr/Prowlarr/Bazarr stack — Jellyfin pipeline.
set -euo pipefail
echo "== media-stack (*arr suite) =="

read -r -p "media library root [/srv/nas/media]: " media
media="${media:-/srv/nas/media}"
mkdir -p "$media"/{tv,movies,downloads}
mkdir -p /srv/arr/{sonarr,radarr,prowlarr,bazarr,qbittorrent}
mkdir -p /opt/stacks/arr

cat >/opt/stacks/arr/docker-compose.yml <<YML
---
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    environment: { PUID: 1000, PGID: 1000, TZ: America/Sao_Paulo }
    volumes:
      - /srv/arr/sonarr:/config
      - $media:/data
    ports: ["127.0.0.1:8989:8989"]
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    environment: { PUID: 1000, PGID: 1000, TZ: America/Sao_Paulo }
    volumes:
      - /srv/arr/radarr:/config
      - $media:/data
    ports: ["127.0.0.1:7878:7878"]
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    environment: { PUID: 1000, PGID: 1000, TZ: America/Sao_Paulo }
    volumes: [/srv/arr/prowlarr:/config]
    ports: ["127.0.0.1:9696:9696"]
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    restart: unless-stopped
    environment: { PUID: 1000, PGID: 1000, TZ: America/Sao_Paulo }
    volumes:
      - /srv/arr/bazarr:/config
      - $media:/data
    ports: ["127.0.0.1:6767:6767"]
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment: { PUID: 1000, PGID: 1000, TZ: America/Sao_Paulo, WEBUI_PORT: 8088 }
    volumes:
      - /srv/arr/qbittorrent:/config
      - $media/downloads:/downloads
    ports: ["127.0.0.1:8088:8088"]
YML

(cd /opt/stacks/arr && docker compose up -d)

cat >/etc/caddy/conf.d/arr.caddy <<'CADDY'
@sonarr   host sonarr.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @sonarr   { reverse_proxy localhost:8989 }
@radarr   host radarr.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @radarr   { reverse_proxy localhost:7878 }
@prowlarr host prowlarr.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @prowlarr { reverse_proxy localhost:9696 }
@bazarr   host bazarr.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @bazarr   { reverse_proxy localhost:6767 }
@qbit     host qbit.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @qbit     { reverse_proxy localhost:8088 }
CADDY
systemctl reload caddy 2>/dev/null || true

echo "*arr stack up. Configure indexers in Prowlarr first, then sync to Sonarr/Radarr."
