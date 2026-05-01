#!/usr/bin/env bash
# Uptime Kuma + Scrutiny + Trivy weekly scan.
set -euo pipefail
echo "== monitoring stack (Uptime Kuma + Scrutiny + Trivy) =="

mkdir -p /opt/stacks/monitoring /srv/monitoring/{kuma,scrutiny}

cat >/opt/stacks/monitoring/docker-compose.yml <<'YML'
---
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports: ["127.0.0.1:3010:3001"]
    volumes: [/srv/monitoring/kuma:/app/data]
  scrutiny:
    image: ghcr.io/analogj/scrutiny:master-omnibus
    container_name: scrutiny
    restart: unless-stopped
    cap_add: [SYS_RAWIO, SYS_ADMIN]
    privileged: true
    ports: ["127.0.0.1:3011:8080"]
    volumes:
      - /run/udev:/run/udev:ro
      - /srv/monitoring/scrutiny:/opt/scrutiny/config
    devices:
      - /dev/sda
YML

(cd /opt/stacks/monitoring && docker compose up -d)

# Trivy weekly scan via cron
if ! command -v trivy >/dev/null; then
  curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add - 2>/dev/null || true
  echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/trivy.list
  apt-get update -qq && apt-get install -y trivy
fi

cat >/etc/cron.d/homeos-trivy <<'CRON'
# weekly Trivy scan of running containers, output to /var/log/homeos-trivy.json
30 3 * * 0 root /usr/local/sbin/homeos-trivy-scan
CRON

cat >/usr/local/sbin/homeos-trivy-scan <<'SH'
#!/usr/bin/env bash
set -euo pipefail
out=/var/log/homeos-trivy.json
echo "[" > "$out"
first=1
docker ps --format '{{.Image}}' | sort -u | while read -r img; do
  [ "$first" = "1" ] || echo "," >> "$out"
  trivy image -f json --severity HIGH,CRITICAL --quiet "$img" >> "$out" || true
  first=0
done
echo "]" >> "$out"
SH
chmod +x /usr/local/sbin/homeos-trivy-scan

cat >/etc/caddy/conf.d/monitoring.caddy <<'CADDY'
@up host up.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @up { reverse_proxy localhost:3010 }
@disks host disks.{$HOMEOS_TAILNET:homeos.example.ts.net}
handle @disks { reverse_proxy localhost:3011 }
CADDY
systemctl reload caddy 2>/dev/null || true

echo "monitoring up:"
echo "  Uptime Kuma → up.<tailnet>.ts.net (proxy via Caddy)"
echo "  Scrutiny    → disks.<tailnet>.ts.net"
echo "  Trivy scan  → weekly Sun 03:30 BRT, results in /var/log/homeos-trivy.json"
