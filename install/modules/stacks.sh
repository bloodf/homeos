#!/usr/bin/env bash
[[ -n "${__HI_MOD_STACKS:-}" ]] && return 0
__HI_MOD_STACKS=1

feature_id="stacks"
feature_name="HomeOS app stacks"
feature_category="Media"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="docker"
feature_risk="medium"

detect() { [[ -d /opt/homeos/stacks ]] || [[ -d /var/lib/homeos/stacks ]]; }
plan() { echo "Deploy compose stacks (jellyfin/arr/etc) via ansible 'stacks' role"; }

apply() {
	if ansible::available && ansible::source_dir >/dev/null; then
		ansible::run_role stacks
		return 0
	fi

	# Standalone: deploy basic stacks without Ansible templates
	ui::info "stacks: deploying standalone compose stacks..."
	local stacks_dir="/opt/homeos/stacks"
	mkdir -p "$stacks_dir"

	# Jellyfin
	mkdir -p "$stacks_dir/jellyfin"
	cat >"$stacks_dir/jellyfin/docker-compose.yml" <<'YAML'
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    network_mode: host
    volumes:
      - jellyfin-config:/config
      - jellyfin-cache:/cache
      - /srv/media:/media:ro
volumes:
  jellyfin-config:
  jellyfin-cache:
YAML

	# Home Assistant
	mkdir -p "$stacks_dir/homeassistant"
	cat >"$stacks_dir/homeassistant/docker-compose.yml" <<'YAML'
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
    volumes:
      - ha-config:/config
      - /run/dbus:/run/dbus:ro
volumes:
  ha-config:
YAML

	# Vaultwarden
	mkdir -p "$stacks_dir/vaultwarden"
	cat >"$stacks_dir/vaultwarden/docker-compose.yml" <<'YAML'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - "8222:80"
    volumes:
      - vw-data:/data
volumes:
  vw-data:
YAML

	# Watchtower
	mkdir -p "$stacks_dir/watchtower"
	cat >"$stacks_dir/watchtower/docker-compose.yml" <<'YAML'
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400 --cleanup
YAML

	# Bring up all stacks
	for d in "$stacks_dir"/*; do
		[[ -f "$d/docker-compose.yml" ]] || continue
		(cd "$d" && docker compose up -d) || ui::warn "failed to start $(basename "$d")"
	done

	ui::ok "stacks: standalone deployment complete"
}

rollback() {
	echo "rollback stacks: bring down compose stacks manually"
}
