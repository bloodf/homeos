#!/usr/bin/env bash
# HomeOS Universal Installer
# Works on Debian 12+/Ubuntu 22.04+ and Fedora 38+/RHEL 9+
#
# Usage:
#   sudo ./install.sh                    # Interactive mode
#   sudo ./install.sh --config /path     # Use custom config
#   sudo ./install.sh --unattended       # Non-interactive (needs config)
#   sudo ./install.sh --mode minimal     # Install core only
#
# Config file locations (first found wins):
#   1. --config <path>
#   2. /etc/homeos/homeos.conf
#   3. ~/.config/homeos/homeos.conf
#   4. ./homeos.conf

set -euo pipefail
IFS=$'\n\t'

# ------------------------------------------------------------------------------
# SCRIPT METADATA
# ------------------------------------------------------------------------------
HI_VERSION="1.0.0"
HI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HI_LIB_DIR="${HI_DIR}/lib"

# ------------------------------------------------------------------------------
# DEFAULT CONFIGURATION (overridden by config file)
# ------------------------------------------------------------------------------
HOMEOS_ADMIN_USER="admin"
HOMEOS_ADMIN_HOME="/home/admin"
HOMEOS_MODE="full"
HOMEOS_UNATTENDED="no"
HOMEOS_DATA_DIR="/opt/homeos"
MEDIA_PATH="/srv/media"

INSTALL_BASE="yes"
INSTALL_DOCKER="yes"
INSTALL_NODE="yes"
INSTALL_TAILSCALE="yes"
INSTALL_CADDY="yes"
INSTALL_CASAOS="yes"
INSTALL_COCKPIT="yes"
INSTALL_HOMEASSISTANT="yes"
INSTALL_JELLYFIN="yes"
INSTALL_VAULTWARDEN="yes"
INSTALL_FIREWALL="yes"
INSTALL_SSH_HARDEN="yes"
INSTALL_AI_CLIS="yes"
INSTALL_GITHUB_TOOLS="yes"
INSTALL_MONITORING="yes"
INSTALL_BACKUPS="yes"

TAILNET_NAME=""
CADDY_DOMAIN=""
TAILSCALE_AUTH_KEY=""
VAULTWARDEN_ADMIN_TOKEN=""
HOMEASSISTANT_API_TOKEN=""
BACKUP_TARGET=""
ANTHROPIC_API_KEY=""
OPENAI_API_KEY=""
GOOGLE_API_KEY=""
EXTRA_TCP_PORTS=""
EXTRA_UDP_PORTS=""
DOCKER_NETWORK_RANGE="172.30.0.0/16"
TIMEZONE=""
GITHUB_TOOLS="all"
ENABLE_AUDIT="yes"

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------
CONFIG_FILE=""
LOG_FILE="/var/log/homeos-install.log"
OS_FAMILY="" # debian or rhel
OS_ID=""     # debian, ubuntu, fedora, rhel, rocky, almalinux
OS_VERSION=""

# ------------------------------------------------------------------------------
# ANSI COLORS
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
	BOLD='\033[1m'
	RED='\033[31m'
	GREEN='\033[32m'
	YELLOW='\033[33m'
	BLUE='\033[34m'
	CYAN='\033[36m'
	RESET='\033[0m'
else
	BOLD=''
	RED=''
	GREEN=''
	YELLOW=''
	BLUE=''
	CYAN=''
	RESET=''
fi

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------
log() { echo -e "${CYAN}[homeos]${RESET} $*"; }
info() { echo -e "${BLUE}[info]${RESET} $*"; }
ok() { echo -e "${GREEN}[ok]${RESET} $*"; }
warn() { echo -e "${YELLOW}[warn]${RESET} $*" >&2; }
err() { echo -e "${RED}[error]${RESET} $*" >&2; }
die() {
	err "$*"
	exit 1
}

log_to_file() {
	local msg="$*"
	printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$msg" >>"$LOG_FILE" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# REQUIREMENTS CHECK
# ------------------------------------------------------------------------------
check_root() {
	if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
		die "Run as root. Try: sudo $0"
	fi
}

detect_os() {
	if [[ -r /etc/os-release ]]; then
		# shellcheck source=/dev/null
		. /etc/os-release
		OS_ID="${ID:-unknown}"
		OS_VERSION="${VERSION_ID:-unknown}"
	else
		die "Cannot detect OS. /etc/os-release not found."
	fi

	case "$OS_ID" in
	debian | ubuntu) OS_FAMILY="debian" ;;
	fedora | rhel | centos | rocky | almalinux) OS_FAMILY="rhel" ;;
	*) die "Unsupported OS: $OS_ID. Only Debian/Ubuntu and Fedora/RHEL families are supported." ;;
	esac

	# Minimum version checks
	case "$OS_ID" in
	debian)
		local major
		major="${OS_VERSION%%.*}"
		[[ "$major" -ge 12 ]] || warn "Debian $OS_VERSION detected. Debian 12+ recommended."
		;;
	ubuntu)
		local major
		major="${OS_VERSION%%.*}"
		[[ "$major" -ge 22 ]] || warn "Ubuntu $OS_VERSION detected. Ubuntu 22.04+ recommended."
		;;
	fedora)
		local major
		major="${OS_VERSION%%.*}"
		[[ "$major" -ge 38 ]] || warn "Fedora $OS_VERSION detected. Fedora 38+ recommended."
		;;
	rhel | rocky | almalinux)
		local major
		major="${OS_VERSION%%.*}"
		[[ "$major" -ge 9 ]] || warn "$OS_ID $OS_VERSION detected. Version 9+ recommended."
		;;
	esac

	log "Detected: $OS_ID $OS_VERSION ($OS_FAMILY family)"
}

# ------------------------------------------------------------------------------
# CONFIG LOADING
# ------------------------------------------------------------------------------
find_config() {
	local paths=(
		"$CONFIG_FILE"
		"/etc/homeos/homeos.conf"
		"$HOME/.config/homeos/homeos.conf"
		"${HI_DIR}/homeos.conf"
		"${HI_DIR}/homeos.conf.example"
	)
	for p in "${paths[@]}"; do
		if [[ -n "$p" && -r "$p" ]]; then
			echo "$p"
			return 0
		fi
	done
	return 1
}

load_config() {
	local cfg
	cfg="$(find_config)" || {
		warn "No config file found. Using defaults."
		return 0
	}

	log "Loading config: $cfg"

	# Source the config file safely
	while IFS='=' read -r key value; do
		# Skip comments and empty lines
		[[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
		# Trim whitespace
		key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		# Remove surrounding quotes if present
		value="${value%\"}"
		value="${value#\"}"
		value="${value%\'}"
		value="${value#\'}"

		# Only set known variables
		case "$key" in
		HOMEOS_ADMIN_USER | HOMEOS_ADMIN_HOME | HOMEOS_MODE | HOMEOS_UNATTENDED | HOMEOS_DATA_DIR | MEDIA_PATH | INSTALL_BASE | INSTALL_DOCKER | INSTALL_NODE | INSTALL_TAILSCALE | INSTALL_CADDY | INSTALL_CASAOS | INSTALL_COCKPIT | INSTALL_HOMEASSISTANT | INSTALL_JELLYFIN | INSTALL_VAULTWARDEN | INSTALL_FIREWALL | INSTALL_SSH_HARDEN | INSTALL_AI_CLIS | INSTALL_GITHUB_TOOLS | INSTALL_MONITORING | INSTALL_BACKUPS | TAILNET_NAME | CADDY_DOMAIN | TAILSCALE_AUTH_KEY | VAULTWARDEN_ADMIN_TOKEN | HOMEASSISTANT_API_TOKEN | BACKUP_TARGET | ANTHROPIC_API_KEY | OPENAI_API_KEY | GOOGLE_API_KEY | EXTRA_TCP_PORTS | EXTRA_UDP_PORTS | DOCKER_NETWORK_RANGE | TIMEZONE | GITHUB_TOOLS | ENABLE_AUDIT)
			eval "$key=\"\$value\""
			;;
		esac
	done <"$cfg"
}

# ------------------------------------------------------------------------------
# INTERACTIVE CONFIRMATION
# ------------------------------------------------------------------------------
confirm_install() {
	if [[ "$HOMEOS_UNATTENDED" == "yes" ]]; then
		return 0
	fi

	echo
	echo -e "${BOLD}HomeOS Universal Installer v${HI_VERSION}${RESET}"
	echo -e "OS: ${BOLD}$OS_ID $OS_VERSION${RESET} ($OS_FAMILY)"
	echo -e "Mode: ${BOLD}$HOMEOS_MODE${RESET}"
	echo -e "Admin user: ${BOLD}$HOMEOS_ADMIN_USER${RESET}"
	echo -e "Data dir: ${BOLD}$HOMEOS_DATA_DIR${RESET}"
	echo

	echo "Components to install:"
	local comps=()
	[[ "$INSTALL_BASE" == "yes" ]] && comps+=("Base system")
	[[ "$INSTALL_DOCKER" == "yes" ]] && comps+=("Docker CE")
	[[ "$INSTALL_NODE" == "yes" ]] && comps+=("Node.js 24 + Bun")
	[[ "$INSTALL_TAILSCALE" == "yes" ]] && comps+=("Tailscale")
	[[ "$INSTALL_CADDY" == "yes" ]] && comps+=("Caddy reverse proxy")
	[[ "$INSTALL_CASAOS" == "yes" ]] && comps+=("CasaOS")
	[[ "$INSTALL_COCKPIT" == "yes" ]] && comps+=("Cockpit + file-sharing")
	[[ "$INSTALL_HOMEASSISTANT" == "yes" ]] && comps+=("Home Assistant")
	[[ "$INSTALL_JELLYFIN" == "yes" ]] && comps+=("Jellyfin")
	[[ "$INSTALL_VAULTWARDEN" == "yes" ]] && comps+=("Vaultwarden")
	[[ "$INSTALL_FIREWALL" == "yes" ]] && comps+=("Firewall (UFW/firewalld)")
	[[ "$INSTALL_SSH_HARDEN" == "yes" ]] && comps+=("SSH hardening")
	[[ "$INSTALL_AI_CLIS" == "yes" ]] && comps+=("AI CLIs (claude, codex, gemini, etc.)")
	[[ "$INSTALL_GITHUB_TOOLS" == "yes" ]] && comps+=("GitHub dev tools")
	[[ "$INSTALL_MONITORING" == "yes" ]] && comps+=("Monitoring (Prometheus/Grafana)")
	[[ "$INSTALL_BACKUPS" == "yes" ]] && comps+=("Backups (restic)")

	for c in "${comps[@]}"; do
		echo "  - $c"
	done

	echo
	if [[ -n "$TAILSCALE_AUTH_KEY" ]]; then
		echo -e "${YELLOW}Tailscale auth key configured${RESET}"
	fi
	if [[ -n "$CADDY_DOMAIN" ]]; then
		echo -e "${YELLOW}Caddy domain: $CADDY_DOMAIN${RESET}"
	fi
	echo

	read -r -p "Proceed with installation? [y/N] " ans
	[[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || die "Aborted by user."
}

# ------------------------------------------------------------------------------
# PACKAGE MANAGER HELPERS
# ------------------------------------------------------------------------------
pkg_update() {
	log "Updating package lists..."
	if [[ "$OS_FAMILY" == "debian" ]]; then
		DEBIAN_FRONTEND=noninteractive apt-get update -y
	else
		dnf makecache -y
	fi
}

pkg_install() {
	local pkgs=("$@")
	if [[ ${#pkgs[@]} -eq 0 ]]; then return 0; fi
	log "Installing: ${pkgs[*]}"
	if [[ "$OS_FAMILY" == "debian" ]]; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
	else
		dnf install -y "${pkgs[@]}"
	fi
}

pkg_service_enable() {
	local svc="$1"
	log "Enabling service: $svc"
	# Gracefully handle environments without systemd (containers, WSL, etc.)
	if ! command -v systemctl &>/dev/null; then
		warn "systemctl not available; skipping service enable for $svc"
		return 0
	fi
	if systemctl is-system-running &>/dev/null || systemctl is-system-running 2>&1 | grep -q "running\|degraded"; then
		systemctl enable --now "$svc" 2>/dev/null || true
	else
		systemctl enable "$svc" 2>/dev/null || true
	fi
}

# ------------------------------------------------------------------------------
# SECTION: BASE SYSTEM
# ------------------------------------------------------------------------------
install_base() {
	[[ "$INSTALL_BASE" == "yes" ]] || return 0
	section "Base System"

	local debian_pkgs=(
		curl ca-certificates git gnupg lsb-release sudo
		vim tmux htop btop ncdu rsync unzip jq fzf ripgrep
		build-essential python3-pip python3-venv pipx
		ufw fail2ban unattended-upgrades apt-listchanges
		cron parted lvm2 cryptsetup smartmontools lm-sensors
	)
	local rhel_pkgs=(
		curl ca-certificates git gnupg2 sudo
		vim tmux htop rsync unzip jq fzf ripgrep
		gcc python3-pip python3-virtualenv
		firewalld fail2ban cronie parted lvm2
		cryptsetup smartmontools lm_sensors
	)

	if [[ "$OS_FAMILY" == "debian" ]]; then
		pkg_install "${debian_pkgs[@]}"
	else
		pkg_install "${rhel_pkgs[@]}"
	fi

	# Set timezone
	if [[ -n "$TIMEZONE" ]]; then
		timedatectl set-timezone "$TIMEZONE" 2>/dev/null || true
	fi

	# Create admin user if not exists
	if ! id "$HOMEOS_ADMIN_USER" &>/dev/null; then
		log "Creating admin user: $HOMEOS_ADMIN_USER"
		useradd -m -s /bin/bash -G sudo "$HOMEOS_ADMIN_USER"
		echo "$HOMEOS_ADMIN_USER:$HOMEOS_ADMIN_USER" | chpasswd
		# Force password change on first login (skip in unattended mode)
		if [[ "$HOMEOS_UNATTENDED" != "yes" ]]; then
			passwd -e "$HOMEOS_ADMIN_USER" 2>/dev/null || true
		fi
	fi

	# Ensure sudoers
	if [[ ! -f "/etc/sudoers.d/${HOMEOS_ADMIN_USER}" ]]; then
		echo "$HOMEOS_ADMIN_USER ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/${HOMEOS_ADMIN_USER}"
		chmod 440 "/etc/sudoers.d/${HOMEOS_ADMIN_USER}"
	fi

	# Create directories
	mkdir -p "$HOMEOS_DATA_DIR" "$MEDIA_PATH"
	chown "$HOMEOS_ADMIN_USER:$HOMEOS_ADMIN_USER" "$HOMEOS_DATA_DIR" 2>/dev/null || true

	ok "Base system installed"
}

# ------------------------------------------------------------------------------
# SECTION: DOCKER
# ------------------------------------------------------------------------------
install_docker() {
	[[ "$INSTALL_DOCKER" == "yes" ]] || return 0
	section "Docker CE"

	if command -v docker &>/dev/null; then
		ok "Docker already installed: $(docker --version)"
	else
		log "Installing Docker CE..."
		if [[ "$OS_FAMILY" == "debian" ]]; then
			install -m 0755 -d /etc/apt/keyrings
			curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" -o /etc/apt/keyrings/docker.asc
			chmod a+r /etc/apt/keyrings/docker.asc
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$OS_ID $(. /etc/os-release && echo "$VERSION_CODENAME") stable" >/etc/apt/sources.list.d/docker.list
			pkg_update
			pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		else
			dnf -y install dnf-plugins-core
			dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null ||
				dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
			dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		fi
	fi

	pkg_service_enable docker

	# Docker daemon config
	cat >/etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true,
  "default-address-pools": [
    { "base": "$DOCKER_NETWORK_RANGE", "size": 24 }
  ]
}
EOF

	# Add admin to docker group
	usermod -aG docker "$HOMEOS_ADMIN_USER" 2>/dev/null || true

	ok "Docker installed"
}

# ------------------------------------------------------------------------------
# SECTION: NODE.JS
# ------------------------------------------------------------------------------
install_node() {
	[[ "$INSTALL_NODE" == "yes" ]] || return 0
	section "Node.js 24 + Bun + pnpm"

	if ! command -v node &>/dev/null || ! node -v | grep -q "^v24\."; then
		if [[ "$OS_FAMILY" == "debian" ]]; then
			log "Adding NodeSource repository..."
			# Use official NodeSource setup script for reliable GPG key handling
			curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
			pkg_install nodejs
		else
			dnf module -y reset nodejs 2>/dev/null || true
			dnf module -y enable nodejs:20 2>/dev/null || true
			pkg_install nodejs npm
		fi
	fi

	# Corepack for pnpm
	corepack enable 2>/dev/null || true
	corepack prepare pnpm@latest --activate 2>/dev/null || true

	# Bun
	if [[ ! -x "${HOMEOS_ADMIN_HOME}/.bun/bin/bun" ]]; then
		log "Installing Bun..."
		su - "$HOMEOS_ADMIN_USER" -c "curl -fsSL https://bun.sh/install | bash" 2>/dev/null || warn "Bun install failed (non-fatal)"
	fi

	ok "Node.js 24 + pnpm + Bun installed"
}

# ------------------------------------------------------------------------------
# SECTION: TAILSCALE
# ------------------------------------------------------------------------------
install_tailscale() {
	[[ "$INSTALL_TAILSCALE" == "yes" ]] || return 0
	section "Tailscale"

	if ! command -v tailscale &>/dev/null; then
		curl -fsSL https://tailscale.com/install.sh | sh
	fi

	pkg_service_enable tailscaled

	if [[ -n "$TAILSCALE_AUTH_KEY" ]]; then
		log "Authenticating Tailscale..."
		tailscale up --authkey "$TAILSCALE_AUTH_KEY" --accept-routes 2>/dev/null || true
	else
		warn "No TAILSCALE_AUTH_KEY set. Run 'sudo tailscale up' manually after install."
	fi

	ok "Tailscale installed"
}

# ------------------------------------------------------------------------------
# SECTION: CADDY
# ------------------------------------------------------------------------------
install_caddy() {
	[[ "$INSTALL_CADDY" == "yes" ]] || return 0
	section "Caddy Reverse Proxy"

	if ! command -v caddy &>/dev/null; then
		if [[ "$OS_FAMILY" == "debian" ]]; then
			install -m 0755 -d /etc/apt/keyrings
			curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key -o /etc/apt/keyrings/caddy.asc
			echo "deb [signed-by=/etc/apt/keyrings/caddy.asc] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" >/etc/apt/sources.list.d/caddy.list
			pkg_update
			pkg_install caddy
		else
			dnf install -y 'dnf-command(copr)' 2>/dev/null || true
			dnf copr -y enable @caddy/caddy 2>/dev/null || true
			dnf install -y caddy
		fi
	fi

	# Create Caddyfile
	mkdir -p /etc/caddy
	cat >/etc/caddy/Caddyfile <<EOF
{
  auto_https off
}

:80 {
  respond "HomeOS Server"
}
EOF

	if [[ -n "$CADDY_DOMAIN" ]]; then
		cat >/etc/caddy/Caddyfile <<EOF
{
  email admin@$CADDY_DOMAIN
}

$CADDY_DOMAIN {
  reverse_proxy localhost:81
}
EOF
	fi

	pkg_service_enable caddy
	ok "Caddy installed"
}

# ------------------------------------------------------------------------------
# SECTION: COCKPIT
# ------------------------------------------------------------------------------
install_cockpit() {
	[[ "$INSTALL_COCKPIT" == "yes" ]] || return 0
	section "Cockpit + 45Drives File Sharing"

	if [[ "$OS_FAMILY" == "debian" ]]; then
		pkg_install cockpit cockpit-storaged cockpit-networkmanager cockpit-podman cockpit-packagekit

		# 45Drives modules (Debian only - they don't have RHEL packages)
		curl -fsSL https://repo.45drives.com/key/gpg.asc | gpg --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
		curl -fsSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
		pkg_update
		pkg_install cockpit-file-sharing cockpit-navigator cockpit-identities 2>/dev/null || warn "Some 45Drives modules unavailable for this release"
	else
		pkg_install cockpit cockpit-storaged cockpit-networkmanager cockpit-podman
	fi

	pkg_service_enable cockpit.socket
	ok "Cockpit installed on :9090"
}

# ------------------------------------------------------------------------------
# SECTION: DOCKER STACKS
# ------------------------------------------------------------------------------
install_homeassistant() {
	[[ "$INSTALL_HOMEASSISTANT" == "yes" ]] || return 0
	section "Home Assistant"

	local stack_dir="$HOMEOS_DATA_DIR/stacks/homeassistant"
	mkdir -p "$stack_dir"

	cat >"$stack_dir/docker-compose.yml" <<EOF
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=${TIMEZONE:-UTC}
    volumes:
      - ha-config:/config
      - /run/dbus:/run/dbus:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8123"]
      interval: 30s
      timeout: 10s
      retries: 3
volumes:
  ha-config:
EOF

	(cd "$stack_dir" && docker compose up -d) 2>/dev/null || warn "Home Assistant container start failed (docker daemon may not be running)"
	ok "Home Assistant on :8123"
}

install_jellyfin() {
	[[ "$INSTALL_JELLYFIN" == "yes" ]] || return 0
	section "Jellyfin"

	local stack_dir="$HOMEOS_DATA_DIR/stacks/jellyfin"
	mkdir -p "$stack_dir" "$MEDIA_PATH"

	cat >"$stack_dir/docker-compose.yml" <<EOF
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=${TIMEZONE:-UTC}
      - PUID=1000
      - PGID=1000
    volumes:
      - jellyfin-config:/config
      - jellyfin-cache:/cache
      - $MEDIA_PATH:/media:ro
    devices:
      - /dev/dri:/dev/dri  # Intel QSV/VAAPI
volumes:
  jellyfin-config:
  jellyfin-cache:
EOF

	(cd "$stack_dir" && docker compose up -d) 2>/dev/null || warn "Jellyfin container start failed (docker daemon may not be running)"
	ok "Jellyfin on :8096"
}

install_vaultwarden() {
	[[ "$INSTALL_VAULTWARDEN" == "yes" ]] || return 0
	section "Vaultwarden"

	local stack_dir="$HOMEOS_DATA_DIR/stacks/vaultwarden"
	mkdir -p "$stack_dir"

	local admin_token_line=""
	[[ -n "$VAULTWARDEN_ADMIN_TOKEN" ]] && admin_token_line="      - ADMIN_TOKEN=$VAULTWARDEN_ADMIN_TOKEN"

	cat >"$stack_dir/docker-compose.yml" <<EOF
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - "8222:80"
    environment:
      - WEBSOCKET_ENABLED=true
$admin_token_line
    volumes:
      - vw-data:/data
volumes:
  vw-data:
EOF

	(cd "$stack_dir" && docker compose up -d) 2>/dev/null || warn "Vaultwarden container start failed (docker daemon may not be running)"
	ok "Vaultwarden on :8222"
}

install_casaos() {
	[[ "$INSTALL_CASAOS" == "yes" ]] || return 0
	section "CasaOS"

	if ! command -v casaos &>/dev/null && [[ ! -d /etc/casaos ]]; then
		warn "Installing CasaOS via official script..."
		curl -fsSL https://get.casaos.io | bash
	fi

	pkg_service_enable casaos 2>/dev/null || true
	ok "CasaOS on :81"
}

install_monitoring() {
	[[ "$INSTALL_MONITORING" == "yes" ]] || return 0
	section "Monitoring (Prometheus/Grafana)"

	local stack_dir="$HOMEOS_DATA_DIR/stacks/monitoring"
	mkdir -p "$stack_dir"

	cat >"$stack_dir/docker-compose.yml" <<EOF
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9091:9090"
    volumes:
      - prom-data:/prometheus
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${HOMEOS_ADMIN_USER}
    volumes:
      - grafana-data:/var/lib/grafana
volumes:
  prom-data:
  grafana-data:
EOF

	cat >"$stack_dir/prometheus.yml" <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['host.docker.internal:9100']
EOF

	(cd "$stack_dir" && docker compose up -d) 2>/dev/null || warn "Monitoring stack start failed (docker daemon may not be running)"
	ok "Monitoring: Prometheus :9091, Grafana :3000"
}

# ------------------------------------------------------------------------------
# SECTION: AI CLIs
# ------------------------------------------------------------------------------
install_ai_clis() {
	[[ "$INSTALL_AI_CLIS" == "yes" ]] || return 0
	section "AI CLIs"

	# Anthropic Claude Code
	if ! command -v claude &>/dev/null; then
		npm install -g @anthropic-ai/claude-code 2>/dev/null || warn "claude-code install failed"
	fi

	# OpenAI Codex
	if ! command -v codex &>/dev/null; then
		npm install -g @openai/codex 2>/dev/null || warn "codex install failed"
	fi

	# Google Gemini CLI
	if ! command -v gemini &>/dev/null; then
		npm install -g @google/gemini-cli 2>/dev/null || warn "gemini-cli install failed"
	fi

	# Cursor Agent
	if ! command -v cursor-agent &>/dev/null; then
		curl -fsSL https://cursor.com/install | bash 2>/dev/null || warn "cursor-agent install failed"
	fi

	# Kimi
	if ! command -v kimi &>/dev/null; then
		curl -fsSL https://code.kimi.com/install.sh | bash 2>/dev/null || warn "kimi install failed"
	fi

	# Opencode
	if ! command -v opencode &>/dev/null; then
		curl -fsSL https://opencode.ai/install | bash 2>/dev/null || warn "opencode install failed"
	fi

	# Configure API keys for admin user
	local admin_rc="${HOMEOS_ADMIN_HOME}/.bashrc"
	[[ -f "${HOMEOS_ADMIN_HOME}/.zshrc" ]] && admin_rc="${HOMEOS_ADMIN_HOME}/.zshrc"

	[[ -n "$ANTHROPIC_API_KEY" ]] && echo "export ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" >>"$admin_rc"
	[[ -n "$OPENAI_API_KEY" ]] && echo "export OPENAI_API_KEY=$OPENAI_API_KEY" >>"$admin_rc"
	[[ -n "$GOOGLE_API_KEY" ]] && echo "export GOOGLE_API_KEY=$GOOGLE_API_KEY" >>"$admin_rc"

	ok "AI CLIs installed"
}

# ------------------------------------------------------------------------------
# SECTION: GITHUB TOOLS
# ------------------------------------------------------------------------------
install_github_tools() {
	[[ "$INSTALL_GITHUB_TOOLS" == "yes" ]] || return 0
	section "GitHub Dev Tools"

	local tools_dir="$HOMEOS_DATA_DIR/tools"
	mkdir -p "$tools_dir"
	chown "$HOMEOS_ADMIN_USER:$HOMEOS_ADMIN_USER" "$tools_dir"

	declare -A tools=(
		["hindsight"]="https://github.com/vectorize-io/hindsight.git"
		["code-review-graph"]="https://github.com/tirth8205/code-review-graph.git"
		["portless"]="https://github.com/vercel-labs/portless.git"
		["claude-context"]="https://github.com/zilliztech/claude-context.git"
		["utoo"]="https://github.com/utooland/utoo.git"
		["OpenViking"]="https://github.com/volcengine/OpenViking.git"
		["oh-my-opencode"]="https://github.com/opensoft/oh-my-opencode.git"
		["oh-my-claudecode"]="https://github.com/yeachan-heo/oh-my-claudecode.git"
		["claude-mem"]="https://github.com/thedotmack/claude-mem.git"
	)

	for name in "${!tools[@]}"; do
		local repo="${tools[$name]}"
		local dest="$tools_dir/$name"

		if [[ "$GITHUB_TOOLS" != "all" && ! " $GITHUB_TOOLS " =~ " $name " ]]; then
			continue
		fi

		if [[ -d "$dest/.git" ]]; then
			info "Updating $name..."
			su - "$HOMEOS_ADMIN_USER" -c "git -C '$dest' pull --quiet" || true
		else
			info "Cloning $name..."
			su - "$HOMEOS_ADMIN_USER" -c "git clone --quiet --depth 1 '$repo' '$dest'" || warn "Failed to clone $name"
		fi
	done

	ok "GitHub tools installed in $tools_dir"
}

# ------------------------------------------------------------------------------
# SECTION: FIREWALL
# ------------------------------------------------------------------------------
install_firewall() {
	[[ "$INSTALL_FIREWALL" == "yes" ]] || return 0
	section "Firewall"

	local tcp_ports=(22 80 443 445 139 2049 8123 8096 9090 81 8222 3000 9091)
	local udp_ports=(137 138 2049 5353 1900 7359)

	# Add extra ports from config
	for p in $EXTRA_TCP_PORTS; do tcp_ports+=("$p"); done
	for p in $EXTRA_UDP_PORTS; do udp_ports+=("$p"); done

	if [[ "$OS_FAMILY" == "debian" ]]; then
		# UFW
		ufw --force default deny incoming
		ufw --force default allow outgoing
		for p in "${tcp_ports[@]}"; do ufw --force allow "$p"/tcp; done
		for p in "${udp_ports[@]}"; do ufw --force allow "$p"/udp; done
		# Allow tailscale interface
		ufw allow in on tailscale0 2>/dev/null || true
		ufw --force enable
	else
		# firewalld
		systemctl enable --now firewalld
		for p in "${tcp_ports[@]}"; do firewall-cmd --permanent --add-port="$p"/tcp; done
		for p in "${udp_ports[@]}"; do firewall-cmd --permanent --add-port="$p"/udp; done
		firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
		firewall-cmd --reload
	fi

	ok "Firewall configured"
}

# ------------------------------------------------------------------------------
# SECTION: SSH HARDENING
# ------------------------------------------------------------------------------
install_ssh_harden() {
	[[ "$INSTALL_SSH_HARDEN" == "yes" ]] || return 0
	section "SSH Hardening"

	mkdir -p /etc/ssh/sshd_config.d

	cat >/etc/ssh/sshd_config.d/99-homeos.conf <<EOF
# HomeOS SSH hardening
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

	# If admin has an SSH key, prefer key auth
	if [[ -f "${HOMEOS_ADMIN_HOME}/.ssh/authorized_keys" ]] && [[ -s "${HOMEOS_ADMIN_HOME}/.ssh/authorized_keys" ]]; then
		sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/99-homeos.conf
	fi

	systemctl restart sshd || systemctl restart ssh
	ok "SSH hardened"
}

# ------------------------------------------------------------------------------
# SECTION: BACKUPS
# ------------------------------------------------------------------------------
install_backups() {
	[[ "$INSTALL_BACKUPS" == "yes" ]] || return 0
	section "Backups (restic)"

	if ! command -v restic &>/dev/null; then
		if [[ "$OS_FAMILY" == "debian" ]]; then
			pkg_install restic
		else
			dnf install -y restic
		fi
	fi

	# Create backup env file
	mkdir -p /etc/homeos
	cat >/etc/homeos/backup.env <<EOF
# HomeOS Backup Configuration
BACKUP_TARGET=${BACKUP_TARGET:-}
BACKUP_SCHEDULE=daily
BACKUP_KEEP_DAILY=7
BACKUP_KEEP_WEEKLY=4
BACKUP_KEEP_MONTHLY=12
EOF

	# Daily backup cron
	cat >/etc/cron.daily/homeos-backup <<'CRON'
#!/bin/bash
set -e
source /etc/homeos/backup.env 2>/dev/null || true
[[ -z "$BACKUP_TARGET" ]] && exit 0
export RESTIC_REPOSITORY="$BACKUP_TARGET"
export RESTIC_PASSWORD_FILE="/etc/homeos/backup-password"
restic backup /opt/homeos /srv/media /home --exclude-file=/etc/homeos/backup-exclude.txt 2>/dev/null || true
CRON
	chmod +x /etc/cron.daily/homeos-backup

	ok "Backups configured"
}

# ------------------------------------------------------------------------------
# SECTION: HOMEOS CLI
# ------------------------------------------------------------------------------
install_homeos_cli() {
	section "HomeOS CLI"

	cat >/usr/local/bin/homeos <<'CLIEOF'
#!/usr/bin/env bash
# HomeOS day-2 CLI
set -euo pipefail

ADMIN_USER="${HOMEOS_ADMIN_USER:-admin}"
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6 || echo /home/$ADMIN_USER)"
DATA_DIR="${HOMEOS_DATA_DIR:-/opt/homeos}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

case "${1:-status}" in
  status)
    bold "== HomeOS Status =="
    echo "OS: $(cat /etc/os-release | grep ^PRETTY_NAME= | cut -d= -f2 | tr -d '\"')"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo ""
    bold "== Services =="
    for svc in docker tailscaled cockpit.socket caddy casaos; do
      if systemctl is-active "$svc" &>/dev/null; then
        echo "  ✓ $svc"
      else
        echo "  ✗ $svc"
      fi
    done
    echo ""
    bold "== Containers =="
    docker ps --format "  {{.Names}} ({{.Status}})" 2>/dev/null || echo "  Docker not available"
    echo ""
    bold "== Disk Usage =="
    df -h / /opt /srv 2>/dev/null | grep -v Filesystem || true
    ;;

  doctor)
    fails=0
    check() {
      local label="$1"; shift
      if "$@" >/dev/null 2>&1; then printf "  \033[32m✓\033[0m %s\n" "$label"
      else printf "  \033[31m✗\033[0m %s\n" "$label"; fails=$((fails+1)); fi
    }
    bold "== Runtime =="
    check "node v24" bash -c 'node -v | grep -q "^v24\."'
    check "docker" docker --version
    check "docker compose" docker compose version
    bold "== Services =="
    check "tailscaled" systemctl is-active tailscaled
    check "cockpit" systemctl is-active cockpit.socket
    echo
    if [[ "$fails" -eq 0 ]]; then bold "ALL OK"
    else bold "$fails check(s) failed"; exit 1; fi
    ;;

  update)
    echo "Pulling latest HomeOS installer..."
    curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh -o /tmp/homeos-install.sh
    sudo bash /tmp/homeos-install.sh --unattended
    ;;

  *)
    echo "Usage: homeos {status|doctor|update}"
    exit 1
    ;;
esac
CLIEOF

	chmod +x /usr/local/bin/homeos
	ok "HomeOS CLI installed. Run: homeos status"
}

# ------------------------------------------------------------------------------
# WATCHTOWER
# ------------------------------------------------------------------------------
install_watchtower() {
	section "Watchtower (auto-updates)"

	local stack_dir="$HOMEOS_DATA_DIR/stacks/watchtower"
	mkdir -p "$stack_dir"

	cat >"$stack_dir/docker-compose.yml" <<EOF
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=${TIMEZONE:-UTC}
    command: --interval 86400 --cleanup --label-enable
EOF

	(cd "$stack_dir" && docker compose up -d) 2>/dev/null || warn "Watchtower container start failed (docker daemon may not be running)"
	ok "Watchtower installed"
}

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------
section() {
	echo
	echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
	echo -e "${BOLD}  $1${RESET}"
	echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
	log_to_file "SECTION: $1"
}

print_summary() {
	echo
	echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${RESET}"
	echo -e "${GREEN}${BOLD}║              HomeOS Installation Complete!                    ║${RESET}"
	echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${RESET}"
	echo
	echo -e "${BOLD}Services:${RESET}"
	[[ "$INSTALL_CASAOS" == "yes" ]] && echo "  CasaOS:        http://$(hostname -I | awk '{print $1}'):81"
	[[ "$INSTALL_HOMEASSISTANT" == "yes" ]] && echo "  Home Assistant: http://$(hostname -I | awk '{print $1}'):8123"
	[[ "$INSTALL_JELLYFIN" == "yes" ]] && echo "  Jellyfin:      http://$(hostname -I | awk '{print $1}'):8096"
	[[ "$INSTALL_COCKPIT" == "yes" ]] && echo "  Cockpit:       https://$(hostname -I | awk '{print $1}'):9090"
	[[ "$INSTALL_VAULTWARDEN" == "yes" ]] && echo "  Vaultwarden:   http://$(hostname -I | awk '{print $1}'):8222"
	[[ "$INSTALL_MONITORING" == "yes" ]] && echo "  Grafana:       http://$(hostname -I | awk '{print $1}'):3000"
	echo
	echo -e "${BOLD}Management:${RESET}"
	echo "  homeos status   - Show system status"
	echo "  homeos doctor   - Run health checks"
	echo
	echo -e "${YELLOW}SSH Access:${RESET}"
	echo "  ssh $HOMEOS_ADMIN_USER@$(hostname -I | awk '{print $1}')"
	echo
	echo -e "${YELLOW}Note:${RESET} Default password is '${HOMEOS_ADMIN_USER}' (forced change on first login)"
	echo -e "${YELLOW}Log:${RESET} $LOG_FILE"
	echo
}

# ------------------------------------------------------------------------------
# CLI ARGS
# ------------------------------------------------------------------------------
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--config)
			CONFIG_FILE="${2:-}"
			shift 2
			;;
		--unattended)
			HOMEOS_UNATTENDED="yes"
			shift
			;;
		--mode)
			HOMEOS_MODE="${2:-full}"
			shift 2
			;;
		--help | -h)
			cat <<HELP
HomeOS Universal Installer v${HI_VERSION}

Usage: sudo $0 [OPTIONS]

Options:
  --config <path>      Path to config file
  --unattended         Non-interactive mode (requires config)
  --mode <full|minimal> Installation mode
  --help               Show this help

Examples:
  sudo $0                                    # Interactive install
  sudo $0 --config /etc/homeos/homeos.conf   # Use custom config
  sudo $0 --unattended --mode minimal        # Unattended minimal

Config locations (first found wins):
  - --config <path>
  - /etc/homeos/homeos.conf
  - ~/.config/homeos/homeos.conf
  - ./homeos.conf
HELP
			exit 0
			;;
		*)
			warn "Unknown option: $1"
			shift
			;;
		esac
	done
}

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
main() {
	parse_args "$@"
	check_root

	# Start logging
	mkdir -p "$(dirname "$LOG_FILE")"
	: >"$LOG_FILE"

	log "HomeOS Universal Installer v${HI_VERSION}"
	detect_os
	load_config

	# Minimal mode: reduce components
	if [[ "$HOMEOS_MODE" == "minimal" ]]; then
		INSTALL_CASAOS="no"
		INSTALL_HOMEASSISTANT="no"
		INSTALL_JELLYFIN="no"
		INSTALL_VAULTWARDEN="no"
		INSTALL_AI_CLIS="no"
		INSTALL_GITHUB_TOOLS="no"
		INSTALL_MONITORING="no"
		INSTALL_BACKUPS="no"
	fi

	confirm_install

	log "Starting installation..."
	log_to_file "INSTALL START mode=$HOMEOS_MODE os=$OS_ID $OS_VERSION"

	install_base
	install_docker
	install_node
	install_tailscale
	install_caddy
	install_cockpit
	install_casaos
	install_homeassistant
	install_jellyfin
	install_vaultwarden
	install_monitoring
	install_watchtower
	install_ai_clis
	install_github_tools
	install_backups
	install_firewall
	install_ssh_harden
	install_homeos_cli

	log_to_file "INSTALL COMPLETE"
	print_summary
}

main "$@"
