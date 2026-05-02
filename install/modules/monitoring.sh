#!/usr/bin/env bash
[[ -n "${__HI_MOD_MON:-}" ]] && return 0
__HI_MOD_MON=1

feature_id="monitoring"
feature_name="Monitoring (Prometheus/Grafana stack)"
feature_category="Monitoring"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="docker"
feature_risk="low"

detect() { docker ps --format '{{.Names}}' 2>/dev/null | grep -qE '^(prometheus|grafana)$'; }
plan() { echo "Deploy monitoring compose stack"; }

apply() {
  if [[ "${HI_DRY_RUN:-0}" == "1" ]]; then
    echo "[monitoring] would deploy prometheus + grafana compose"
    return 0
  fi
  local target="/opt/homeos/stacks/monitoring"
  mkdir -p "$target"
  cat > "$target/compose.yml" <<'YAML'
services:
  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    ports: ["9090:9090"]
    volumes:
      - prom-data:/prometheus
  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    ports: ["3000:3000"]
    volumes:
      - grafana-data:/var/lib/grafana
volumes:
  prom-data: {}
  grafana-data: {}
YAML
  ( cd "$target" && docker compose up -d ) || return 1
}

rollback() {
  [[ "${HI_DRY_RUN:-0}" == "1" ]] && return 0
  ( cd /opt/homeos/stacks/monitoring && docker compose down ) 2>/dev/null || true
}
