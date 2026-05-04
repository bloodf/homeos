#!/usr/bin/env bash
# HomeOS Universal Installer v1.2.0
# Works on Debian 12+/Ubuntu 22.04+ and Fedora 38+/RHEL 9+
#
# Usage:
#   sudo ./install.sh                    # Interactive mode
#   sudo ./install.sh --config /path     # Use custom config
#   sudo ./install.sh --unattended       # Non-interactive (needs config)
#   sudo ./install.sh --mode minimal     # Install core only
#   sudo ./install.sh --dry-run          # Preview what would be installed
#   sudo ./install.sh uninstall          # Remove HomeOS
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
HI_VERSION="1.2.0"
HI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_STATE_DIR="/var/lib/homeos"
DRY_RUN="no"
SKIP_CHECKS="no"
YES_FLAG="no"
COMMAND="install"
UNINSTALL_PURGE_PACKAGES="no"

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
INSTALL_LOCAL_DOMAINS="yes"
INSTALL_COOLIFY="yes"
INSTALL_CASAOS="yes"
INSTALL_COCKPIT="yes"
INSTALL_HOMEASSISTANT="yes"
INSTALL_JELLYFIN="yes"
INSTALL_VAULTWARDEN="yes"
INSTALL_FIREWALL="yes"
INSTALL_SSH_HARDEN="yes"
INSTALL_AI_CLIS="yes"
INSTALL_PI="yes"
INSTALL_AI_SKILLS="yes"
INSTALL_AI_PROJECTS="yes"
INSTALL_GITHUB_TOOLS="yes"
INSTALL_MONITORING="yes"
INSTALL_BACKUPS="yes"

TAILNET_NAME=""
CADDY_DOMAIN=""
LOCAL_DOMAIN_ROOT="homeos.home.arpa"
LOCAL_DOMAIN_SERVER_IP=""
TAILSCALE_AUTH_KEY=""
VAULTWARDEN_ADMIN_TOKEN=""
BACKUP_TARGET=""
ANTHROPIC_API_KEY=""
OPENAI_API_KEY=""
GOOGLE_API_KEY=""
EXTRA_TCP_PORTS=""
EXTRA_UDP_PORTS=""
DOCKER_NETWORK_RANGE="172.30.0.0/16"
TIMEZONE=""
GITHUB_TOOLS="all"
PI_PACKAGES="npm:context-mode npm:pi-subagents npm:pi-mcp-adapter npm:pi-lens npm:pi-gsd npm:pi-powerline-footer npm:pi-web-access npm:pi-interactive-shell npm:@a5c-ai/babysitter-pi npm:@plannotator/pi-extension npm:taskplane npm:pi-markdown-preview npm:@aliou/pi-processes npm:@callumvass/forgeflow-dev npm:@juicesharp/rpiv-todo npm:@juicesharp/rpiv-ask-user-question npm:@samfp/pi-memory npm:pi-mermaid"
AI_SKILL_INSTALLS="vercel-labs/skills|claude-code,codex,opencode,pi|find-skills;vercel-labs/agent-skills|claude-code,codex,opencode,pi|vercel-react-best-practices,web-design-guidelines,vercel-composition-patterns,vercel-react-native-skills;anthropics/skills|claude-code,codex,opencode,pi|frontend-design;Leonxlnx/taste-skill|claude-code,codex,opencode,pi|*;obra/superpowers|claude-code,codex,opencode,pi|brainstorming,subagent-driven-development,writing-plans;expo/skills|claude-code,codex,opencode|building-native-ui,expo-api-routes,expo-cicd-workflows,expo-deployment,expo-dev-client,expo-tailwind-setup,native-data-fetching,upgrading-expo,use-dom;JuliusBrussee/caveman|claude-code,pi|*;railwayapp/railway-skills|claude-code,codex,opencode|use-railway;callstackincubator/agent-skills|claude-code,codex,opencode|github,react-native-best-practices,upgrading-react-native,validate-skills;wshobson/agents|claude-code,codex,opencode|tailwind-design-system,typescript-advanced-types;vercel-labs/agent-browser|claude-code,codex,opencode|agent-browser;browser-use/browser-use|claude-code,codex,opencode|browser-use;vercel-labs/next-skills|claude-code,codex,opencode|next-best-practices;hyf0/vue-skills|claude-code,codex,opencode|vue-best-practices,vue-debug-guides;MiniMax-AI/cli|claude-code,codex,opencode|mmx-cli;microsoft/azure-skills|claude-code,codex,opencode|microsoft-foundry;nextlevelbuilder/ui-ux-pro-max-skill|claude-code,codex,opencode|ui-ux-pro-max;laurigates/mcu-tinkering-lab|claude-code,codex,opencode|esp32-debugging"
AI_PROJECTS="all"
AI_PROJECT_TOOLS="claude,opencode,openagent,pi,codex,cursor,gemini"
AI_PROJECT_TARGETS=""
AI_PROJECT_INSTALL_MODE="clone"
GRAFANA_ADMIN_PASSWORD=""
GRAFANA_BIND_ADDRESS="127.0.0.1"

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------
CONFIG_FILE=""
LOG_FILE="/var/log/homeos-install.log"
OS_FAMILY=""
OS_ID=""
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

generate_secret() {
	if command -v openssl &>/dev/null && openssl rand -base64 24 2>/dev/null; then
		return 0
	fi

	local secret
	secret="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 24 || true)"
	printf '%s\n' "$secret"
}

# ------------------------------------------------------------------------------
# REQUIREMENTS CHECK
# ------------------------------------------------------------------------------
check_root() {
	if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
		die "Run as root. Try: sudo $0"
	fi
}

preflight_checks() {
	[[ "$SKIP_CHECKS" == "yes" ]] && return 0
	section "Pre-Flight Checks"
	local fails=0

	if [[ "$DRY_RUN" == "yes" ]]; then
		info "Would check: disk space (>=10GB), RAM (>=2GB), internet, OS compatibility"
		return 0
	fi

	local avail_gb
	avail_gb="$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')"
	if [[ "$avail_gb" -lt 10 ]]; then
		warn "Low disk space: ${avail_gb}GB available. 10GB+ recommended."
		fails=$((fails + 1))
	else
		ok "Disk space: ${avail_gb}GB available"
	fi

	local ram_mb
	ram_mb="$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo || echo 0)"
	if [[ "$ram_mb" -eq 0 ]]; then
		warn "Could not detect RAM (container environment?). Skipping RAM check."
	elif [[ "$ram_mb" -lt 2048 ]]; then
		warn "Low RAM: ${ram_mb}MB. 2GB+ recommended (4GB for full mode)."
		fails=$((fails + 1))
	else
		ok "RAM: ${ram_mb}MB available"
	fi

	if curl -fsSL --max-time 10 https://github.com >/dev/null 2>&1; then
		ok "Internet connectivity"
	else
		err "No internet connectivity. Check your network."
		fails=$((fails + 1))
	fi

	case "$OS_ID" in
	debian | ubuntu | fedora | rhel | rocky | almalinux) ok "OS supported: $OS_ID $OS_VERSION" ;;
	*)
		err "Unsupported OS: $OS_ID"
		fails=$((fails + 1))
		;;
	esac

	if [[ "$fails" -gt 0 ]]; then
		die "$fails pre-flight check(s) failed. Fix issues or use --skip-checks to bypass."
	fi

	ok "All pre-flight checks passed"
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

expand_config_value() {
	local value="$1" var_name

	if [[ "$value" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
		var_name="${BASH_REMATCH[1]}"
		printf '%s' "${!var_name-}"
	elif [[ "$value" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)$ ]]; then
		var_name="${BASH_REMATCH[1]}"
		printf '%s' "${!var_name-}"
	else
		printf '%s' "$value"
	fi
}

load_config() {
	local cfg
	cfg="$(find_config)" || {
		warn "No config file found. Using defaults."
		return 0
	}

	log "Loading config: $cfg"
	CONFIG_FILE="$cfg"

	while IFS='=' read -r key value; do
		[[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
		key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		value="${value%\"}"
		value="${value#\"}"
		value="${value%\'}"
		value="${value#\'}"
		value="$(expand_config_value "$value")"

		case "$key" in
		HOMEOS_ADMIN_USER | HOMEOS_ADMIN_HOME | HOMEOS_MODE | HOMEOS_UNATTENDED | HOMEOS_DATA_DIR | MEDIA_PATH | INSTALL_BASE | INSTALL_DOCKER | INSTALL_NODE | INSTALL_TAILSCALE | INSTALL_CADDY | INSTALL_LOCAL_DOMAINS | INSTALL_COOLIFY | INSTALL_CASAOS | INSTALL_COCKPIT | INSTALL_HOMEASSISTANT | INSTALL_JELLYFIN | INSTALL_VAULTWARDEN | INSTALL_FIREWALL | INSTALL_SSH_HARDEN | INSTALL_AI_CLIS | INSTALL_PI | INSTALL_AI_SKILLS | INSTALL_AI_PROJECTS | INSTALL_GITHUB_TOOLS | INSTALL_MONITORING | INSTALL_BACKUPS | TAILNET_NAME | CADDY_DOMAIN | LOCAL_DOMAIN_ROOT | LOCAL_DOMAIN_SERVER_IP | TAILSCALE_AUTH_KEY | VAULTWARDEN_ADMIN_TOKEN | BACKUP_TARGET | ANTHROPIC_API_KEY | OPENAI_API_KEY | GOOGLE_API_KEY | EXTRA_TCP_PORTS | EXTRA_UDP_PORTS | DOCKER_NETWORK_RANGE | TIMEZONE | GITHUB_TOOLS | PI_PACKAGES | AI_SKILL_INSTALLS | AI_PROJECTS | AI_PROJECT_TOOLS | AI_PROJECT_TARGETS | AI_PROJECT_INSTALL_MODE | GRAFANA_ADMIN_PASSWORD | GRAFANA_BIND_ADDRESS)
			printf -v "$key" '%s' "$value"
			;;
		esac
	done <"$cfg"
}

# ------------------------------------------------------------------------------
# INTERACTIVE CONFIGURATION
# ------------------------------------------------------------------------------
have_interactive_checklist() {
	command -v whiptail >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]
}

set_component_flag() {
	case "$1" in
	base) INSTALL_BASE="yes" ;;
	docker) INSTALL_DOCKER="yes" ;;
	node) INSTALL_NODE="yes" ;;
	tailscale) INSTALL_TAILSCALE="yes" ;;
	caddy) INSTALL_CADDY="yes" ;;
	local-domains) INSTALL_LOCAL_DOMAINS="yes" ;;
	coolify) INSTALL_COOLIFY="yes" ;;
	casaos) INSTALL_CASAOS="yes" ;;
	cockpit) INSTALL_COCKPIT="yes" ;;
	homeassistant) INSTALL_HOMEASSISTANT="yes" ;;
	jellyfin) INSTALL_JELLYFIN="yes" ;;
	vaultwarden) INSTALL_VAULTWARDEN="yes" ;;
	firewall) INSTALL_FIREWALL="yes" ;;
	ssh-harden) INSTALL_SSH_HARDEN="yes" ;;
	ai-clis) INSTALL_AI_CLIS="yes" ;;
	pi) INSTALL_PI="yes" ;;
	ai-skills) INSTALL_AI_SKILLS="yes" ;;
	ai-projects) INSTALL_AI_PROJECTS="yes" ;;
	github-tools) INSTALL_GITHUB_TOOLS="yes" ;;
	monitoring) INSTALL_MONITORING="yes" ;;
	backups) INSTALL_BACKUPS="yes" ;;
	esac
}

reset_component_flags() {
	INSTALL_BASE="no"
	INSTALL_DOCKER="no"
	INSTALL_NODE="no"
	INSTALL_TAILSCALE="no"
	INSTALL_CADDY="no"
	INSTALL_LOCAL_DOMAINS="no"
	INSTALL_COOLIFY="no"
	INSTALL_CASAOS="no"
	INSTALL_COCKPIT="no"
	INSTALL_HOMEASSISTANT="no"
	INSTALL_JELLYFIN="no"
	INSTALL_VAULTWARDEN="no"
	INSTALL_FIREWALL="no"
	INSTALL_SSH_HARDEN="no"
	INSTALL_AI_CLIS="no"
	INSTALL_PI="no"
	INSTALL_AI_SKILLS="no"
	INSTALL_AI_PROJECTS="no"
	INSTALL_GITHUB_TOOLS="no"
	INSTALL_MONITORING="no"
	INSTALL_BACKUPS="no"
}

select_components_with_help() {
	have_interactive_checklist || return 0
	[[ "$YES_FLAG" == "yes" || "$DRY_RUN" == "yes" ]] && return 0
	whiptail --yesno "Open an interactive checklist? Arrow over an item to see help for what it installs and what to think about before enabling it." 12 78 || return 0

	local selected tag
	local -a items=(
		base "Base system" "$([[ "$INSTALL_BASE" == "yes" ]] && echo ON || echo OFF)" "Core packages, admin user, sudoers, directories, unattended-safe defaults. Keep enabled for real installs."
		docker "Docker CE" "$([[ "$INSTALL_DOCKER" == "yes" ]] && echo ON || echo OFF)" "Container runtime required by most HomeOS app stacks. Think about existing Docker installs and network ranges."
		node "Node.js" "$([[ "$INSTALL_NODE" == "yes" ]] && echo ON || echo OFF)" "Node.js, npm, pnpm, Bun. Required for many AI CLIs, npx skills, and JS tooling."
		tailscale "Tailscale" "$([[ "$INSTALL_TAILSCALE" == "yes" ]] && echo ON || echo OFF)" "Private tailnet access. Provide auth key for unattended setup or log in manually later."
		caddy "Caddy" "$([[ "$INSTALL_CADDY" == "yes" ]] && echo ON || echo OFF)" "Reverse proxy for local domains and app routes. Think about port 80/443 conflicts."
		local-domains "Local domains" "$([[ "$INSTALL_LOCAL_DOMAINS" == "yes" ]] && echo ON || echo OFF)" "dnsmasq wildcard DNS such as *.homeos.home.arpa. Requires router/client DNS pointing at HomeOS."
		coolify "Coolify" "$([[ "$INSTALL_COOLIFY" == "yes" ]] && echo ON || echo OFF)" "Self-hosted app platform. Best on Ubuntu LTS; installer failure is non-fatal on unsupported systems."
		casaos "CasaOS" "$([[ "$INSTALL_CASAOS" == "yes" ]] && echo ON || echo OFF)" "Friendly server dashboard on port 81. Useful for non-terminal administration."
		cockpit "Cockpit" "$([[ "$INSTALL_COCKPIT" == "yes" ]] && echo ON || echo OFF)" "Linux web administration and file sharing modules. Opens/uses port 9090."
		homeassistant "Home Assistant" "$([[ "$INSTALL_HOMEASSISTANT" == "yes" ]] && echo ON || echo OFF)" "Home automation stack on port 8123. Think about device discovery and LAN access."
		jellyfin "Jellyfin" "$([[ "$INSTALL_JELLYFIN" == "yes" ]] && echo ON || echo OFF)" "Media server on port 8096. Think about media paths and disk size."
		vaultwarden "Vaultwarden" "$([[ "$INSTALL_VAULTWARDEN" == "yes" ]] && echo ON || echo OFF)" "Bitwarden-compatible password vault. Set a strong admin token before internet exposure."
		firewall "Firewall" "$([[ "$INSTALL_FIREWALL" == "yes" ]] && echo ON || echo OFF)" "UFW/firewalld rules for HomeOS ports. Review if this machine already has custom rules."
		ssh-harden "SSH hardening" "$([[ "$INSTALL_SSH_HARDEN" == "yes" ]] && echo ON || echo OFF)" "Disables root SSH and tightens auth. With SSH keys, password auth is disabled."
		ai-clis "AI CLIs" "$([[ "$INSTALL_AI_CLIS" == "yes" ]] && echo ON || echo OFF)" "Claude Code, Codex, Gemini, Cursor Agent, Kimi, OpenCode. Needs API keys/logins per tool."
		pi "Pi agent" "$([[ "$INSTALL_PI" == "yes" ]] && echo ON || echo OFF)" "Installs pi.dev coding agent and configured Pi npm packages."
		ai-skills "AI skills" "$([[ "$INSTALL_AI_SKILLS" == "yes" ]] && echo ON || echo OFF)" "Uses npx skills to install selected skill packages into selected supported agents."
		ai-projects "AI projects" "$([[ "$INSTALL_AI_PROJECTS" == "yes" ]] && echo ON || echo OFF)" "Clones helper AI repos and links selected tools. Shares skills/agents, isolates MCP/plugins."
		github-tools "GitHub tools" "$([[ "$INSTALL_GITHUB_TOOLS" == "yes" ]] && echo ON || echo OFF)" "Clones selected GitHub helper tools into HomeOS data dir."
		monitoring "Monitoring" "$([[ "$INSTALL_MONITORING" == "yes" ]] && echo ON || echo OFF)" "Prometheus, node-exporter, Grafana dashboard. Grafana binds to localhost by default."
		backups "Backups" "$([[ "$INSTALL_BACKUPS" == "yes" ]] && echo ON || echo OFF)" "Restic backup tooling and daily job when BACKUP_TARGET is configured."
	)
	if selected="$(whiptail --title "HomeOS components" --separate-output --item-help --checklist "Select components. The help line explains the highlighted item." 28 100 18 "${items[@]}" 3>&1 1>&2 2>&3)"; then
		reset_component_flags
		while IFS= read -r tag; do set_component_flag "$tag"; done <<<"$selected"
	fi
}

skill_source_help() {
	case "$1" in
	vercel-labs/skills) printf '%s\n' "Skill discovery and installation helpers." ;;
	vercel-labs/agent-skills) printf '%s\n' "Vercel React, composition, RN, and web design guideline skills." ;;
	anthropics/skills) printf '%s\n' "Official Anthropic skills such as frontend-design." ;;
	Leonxlnx/taste-skill) printf '%s\n' "High-taste UI/design skills that reduce generic AI output." ;;
	obra/superpowers) printf '%s\n' "Software craft workflow skills: brainstorming, planning, TDD-style execution." ;;
	expo/skills) printf '%s\n' "Expo and React Native app, deployment, API route, and upgrade skills." ;;
	JuliusBrussee/caveman) printf '%s\n' "Compressed communication and commit/review helpers." ;;
	railwayapp/railway-skills) printf '%s\n' "Railway infrastructure and deployment operations." ;;
	callstackincubator/agent-skills) printf '%s\n' "GitHub and React Native engineering skills from Callstack." ;;
	wshobson/agents) printf '%s\n' "Tailwind design system and TypeScript advanced type skills." ;;
	vercel-labs/agent-browser) printf '%s\n' "Browser automation skill for screenshots, forms, scraping, and testing." ;;
	browser-use/browser-use) printf '%s\n' "Browser-use automation skill." ;;
	vercel-labs/next-skills) printf '%s\n' "Next.js best practices skill." ;;
	hyf0/vue-skills) printf '%s\n' "Vue best practices and debugging skills." ;;
	MiniMax-AI/cli) printf '%s\n' "MiniMax CLI media/model generation skill." ;;
	microsoft/azure-skills) printf '%s\n' "Microsoft Foundry/Azure agent deployment and evaluation skill." ;;
	nextlevelbuilder/ui-ux-pro-max-skill) printf '%s\n' "Broad UI/UX design intelligence skill." ;;
	laurigates/mcu-tinkering-lab) printf '%s\n' "ESP32 and embedded firmware debugging skill." ;;
	*) printf '%s\n' "External skill package installed via npx skills." ;;
	esac
}

select_ai_skills_with_help() {
	have_interactive_checklist || return 0
	[[ "$INSTALL_AI_SKILLS" == "yes" && "$YES_FLAG" != "yes" && "$DRY_RUN" != "yes" ]] || return 0

	local entry source agents skills selected_sources selected_agents selected help new_installs=""
	local -a package_items=()
	while IFS= read -r entry; do
		source="${entry%%|*}"
		[[ -n "$source" ]] || continue
		help="$(skill_source_help "$source")"
		package_items+=("$source" "$source" ON "$help")
	done < <(emit_records "$AI_SKILL_INSTALLS")

	if [[ ${#package_items[@]} -gt 0 ]]; then
		if selected_sources="$(whiptail --title "AI skill packages" --separate-output --item-help --checklist "Select any skill packages. Help explains each package." 28 110 18 "${package_items[@]}" 3>&1 1>&2 2>&3)"; then
			local -a agent_items=(
				claude-code "Claude Code" ON "Supported by npx skills; installs into Claude Code global skills."
				codex "Codex" ON "Supported by npx skills; installs into Codex global skills."
				opencode "OpenCode" ON "Supported by npx skills when available; keeps OpenCode separate from Claude config."
				pi "Pi" ON "Supported by npx skills; installs into Pi's own skill location."
				cursor "Cursor" OFF "Supported by npx skills on some systems; enable if you use Cursor Agent."
				kimi "Kimi" OFF "Mapped to npx skills agent kimi-cli; enable if you use Kimi CLI."
				gemini "Gemini" OFF "Mapped to npx skills agent gemini-cli; enable if you use Gemini CLI."
			)
			selected_agents="$(whiptail --title "AI skill target agents" --separate-output --item-help --checklist "Select target agents. Unsupported agents are shown so you know why they are skipped." 22 100 10 "${agent_items[@]}" 3>&1 1>&2 2>&3)" || selected_agents=""
			while IFS= read -r selected; do
				while IFS= read -r entry; do
					source="${entry%%|*}"
					[[ "$source" == "$selected" ]] || continue
					agents="${selected_agents//$'\n'/,}"
					[[ -n "$agents" ]] || agents="claude-code,codex,opencode,pi"
					skills="${entry##*|}"
					[[ -n "$new_installs" ]] && new_installs+=";"
					new_installs+="${source}|${agents}|${skills}"
				done < <(emit_records "$AI_SKILL_INSTALLS")
			done <<<"$selected_sources"
			AI_SKILL_INSTALLS="$new_installs"
		fi
	fi
}

# ------------------------------------------------------------------------------
# INTERACTIVE CONFIRMATION
# ------------------------------------------------------------------------------
confirm_install() {
	if [[ "$HOMEOS_UNATTENDED" == "yes" ]]; then
		return 0
	fi

	select_components_with_help
	select_ai_skills_with_help

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
	[[ "$INSTALL_LOCAL_DOMAINS" == "yes" ]] && comps+=("Local custom domains")
	[[ "$INSTALL_COOLIFY" == "yes" ]] && comps+=("Coolify app platform")
	[[ "$INSTALL_CASAOS" == "yes" ]] && comps+=("CasaOS")
	[[ "$INSTALL_COCKPIT" == "yes" ]] && comps+=("Cockpit + file-sharing")
	[[ "$INSTALL_HOMEASSISTANT" == "yes" ]] && comps+=("Home Assistant")
	[[ "$INSTALL_JELLYFIN" == "yes" ]] && comps+=("Jellyfin")
	[[ "$INSTALL_VAULTWARDEN" == "yes" ]] && comps+=("Vaultwarden")
	[[ "$INSTALL_FIREWALL" == "yes" ]] && comps+=("Firewall (UFW/firewalld)")
	[[ "$INSTALL_SSH_HARDEN" == "yes" ]] && comps+=("SSH hardening")
	[[ "$INSTALL_AI_CLIS" == "yes" ]] && comps+=("AI CLIs (claude, codex, gemini, etc.)")
	[[ "$INSTALL_PI" == "yes" ]] && comps+=("Pi coding agent + packages")
	[[ "$INSTALL_AI_SKILLS" == "yes" ]] && comps+=("Selectable npx skills")
	[[ "$INSTALL_AI_PROJECTS" == "yes" ]] && comps+=("Shared/isolated AI project library")
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

	if [[ "$YES_FLAG" == "yes" ]]; then
		ok "Auto-accepting (--yes)"
		return 0
	fi
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
	if [[ "$DRY_RUN" == "yes" ]]; then
		info "Would install: ${pkgs[*]}"
		return 0
	fi
	log "Installing: ${pkgs[*]}"
	if [[ "$OS_FAMILY" == "debian" ]]; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
	else
		dnf install -y "${pkgs[@]}"
	fi
}

pkg_remove_if_installed() {
	local candidates=("$@") installed=() pkg
	[[ ${#candidates[@]} -gt 0 ]] || return 0

	if [[ "$OS_FAMILY" == "debian" ]]; then
		for pkg in "${candidates[@]}"; do
			if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
				installed+=("$pkg")
			fi
		done
		[[ ${#installed[@]} -gt 0 ]] || return 0
		log "Removing packages: ${installed[*]}"
		DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge "${installed[@]}" || warn "Some package removals failed"
		DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
	else
		for pkg in "${candidates[@]}"; do
			if rpm -q "$pkg" >/dev/null 2>&1; then
				installed+=("$pkg")
			fi
		done
		[[ ${#installed[@]} -gt 0 ]] || return 0
		log "Removing packages: ${installed[*]}"
		dnf remove -y "${installed[@]}" || warn "Some package removals failed"
	fi
}

pkg_service_enable() {
	local svc="$1"
	log "Enabling service: $svc"
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

get_primary_ip() {
	local ip=""
	ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
	if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
		ip="$(ip -4 route get 1 2>/dev/null | awk '{print $7; exit}' || true)"
	fi
	printf '%s\n' "${ip:-127.0.0.1}"
}

sanitize_domain_label() {
	local label="$1"
	label="${label,,}"
	label="${label//[^a-z0-9-]/-}"
	label="${label#-}"
	label="${label%-}"
	[[ -n "$label" ]] || return 1
	printf '%s\n' "$label"
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

	if [[ -n "$TIMEZONE" ]]; then
		timedatectl set-timezone "$TIMEZONE" 2>/dev/null || true
	fi

	local sudo_group="sudo"
	[[ "$OS_FAMILY" == "rhel" ]] && sudo_group="wheel"

	if ! id "$HOMEOS_ADMIN_USER" &>/dev/null; then
		log "Creating admin user: $HOMEOS_ADMIN_USER"
		useradd -m -s /bin/bash -G "$sudo_group" "$HOMEOS_ADMIN_USER"

		local admin_pass
		if [[ -n "${HOMEOS_ADMIN_PASSWORD:-}" ]]; then
			admin_pass="$HOMEOS_ADMIN_PASSWORD"
		elif [[ "$HOMEOS_UNATTENDED" == "yes" ]]; then
			admin_pass="$(generate_secret)"
			log_to_file "GENERATED_PASSWORD"
			mkdir -p "$INSTALL_STATE_DIR"
			chmod 700 "$INSTALL_STATE_DIR"
			echo "$admin_pass" >"$INSTALL_STATE_DIR/admin-password.txt"
			chmod 600 "$INSTALL_STATE_DIR/admin-password.txt"
			warn "Generated random admin password. Retrieve with: sudo cat $INSTALL_STATE_DIR/admin-password.txt"
		else
			admin_pass="$HOMEOS_ADMIN_USER"
		fi
		echo "$HOMEOS_ADMIN_USER:$admin_pass" | chpasswd

		if [[ "$HOMEOS_UNATTENDED" != "yes" && -z "${HOMEOS_ADMIN_PASSWORD:-}" ]]; then
			passwd -e "$HOMEOS_ADMIN_USER" 2>/dev/null || true
		fi
	else
		# Ensure existing user is in the correct groups
		if ! id -nG "$HOMEOS_ADMIN_USER" | grep -qw "$sudo_group"; then
			log "Adding $HOMEOS_ADMIN_USER to $sudo_group group"
			usermod -aG "$sudo_group" "$HOMEOS_ADMIN_USER"
		fi
		if command -v docker &>/dev/null && ! id -nG "$HOMEOS_ADMIN_USER" | grep -qw "docker"; then
			usermod -aG docker "$HOMEOS_ADMIN_USER" 2>/dev/null || true
		fi
	fi

	if [[ ! -f "/etc/sudoers.d/${HOMEOS_ADMIN_USER}" ]]; then
		echo "$HOMEOS_ADMIN_USER ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/${HOMEOS_ADMIN_USER}"
		chmod 440 "/etc/sudoers.d/${HOMEOS_ADMIN_USER}"
	fi

	mkdir -p "$HOMEOS_DATA_DIR" "$MEDIA_PATH"
	chown "$HOMEOS_ADMIN_USER:$HOMEOS_ADMIN_USER" "$HOMEOS_DATA_DIR" 2>/dev/null || true

	# Enable services
	pkg_service_enable fail2ban
	if [[ "$OS_FAMILY" == "debian" ]]; then
		pkg_service_enable unattended-upgrades
		# Configure unattended-upgrades to auto-install security updates
		if [[ -f /usr/bin/unattended-upgrade ]]; then
			sed -i 's|//[[:space:]]*"\${distro_id}:\${distro_codename}-security";|"${distro_id}:${distro_codename}-security";|' /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true
		fi
	fi

	echo "base=$(date -u +%FT%TZ)" >>"$INSTALL_STATE_DIR/install.state" 2>/dev/null || true

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
			local docker_repo="fedora"
			[[ "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" ]] && docker_repo="centos"
			dnf config-manager --add-repo "https://download.docker.com/linux/${docker_repo}/docker-ce.repo"
			dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		fi
	fi

	pkg_service_enable docker

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

	# Ensure docker group exists and admin is in it
	getent group docker &>/dev/null || groupadd docker
	usermod -aG docker "$HOMEOS_ADMIN_USER" 2>/dev/null || true

	echo "docker=$(date -u +%FT%TZ)" >>"$INSTALL_STATE_DIR/install.state" 2>/dev/null || true

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
			curl -fsSL https://deb.nodesource.com/setup_24.x | bash - || warn "NodeSource setup failed (non-fatal)"
			pkg_install nodejs
		else
			dnf module -y reset nodejs 2>/dev/null || true
			dnf module -y enable nodejs:20 2>/dev/null || true
			pkg_install nodejs npm
		fi
	fi

	corepack enable 2>/dev/null || true
	corepack prepare pnpm@latest --activate 2>/dev/null || true

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
		curl -fsSL https://tailscale.com/install.sh | sh || warn "Tailscale install failed (non-fatal)"
	fi

	pkg_service_enable tailscaled

	if [[ -n "$TAILSCALE_AUTH_KEY" ]]; then
		log "Authenticating Tailscale..."
		local ts_args=(--authkey "$TAILSCALE_AUTH_KEY" --accept-routes)
		[[ -n "$TAILNET_NAME" ]] && ts_args+=(--hostname "$TAILNET_NAME")
		tailscale up "${ts_args[@]}" 2>/dev/null || true
	else
		warn "No TAILSCALE_AUTH_KEY set. Run 'sudo tailscale up' manually after install."
	fi

	ok "Tailscale installed"
}

# ------------------------------------------------------------------------------
# SECTION: LOCAL DOMAINS
# ------------------------------------------------------------------------------
install_local_domains() {
	[[ "$INSTALL_LOCAL_DOMAINS" == "yes" ]] || return 0
	section "Local Custom Domains"

	local server_ip="$LOCAL_DOMAIN_SERVER_IP"
	[[ -n "$server_ip" ]] || server_ip="$(get_primary_ip)"
	mkdir -p /etc/homeos /etc/caddy/conf.d /etc/dnsmasq.d
	printf '%s\n' "$LOCAL_DOMAIN_ROOT" >/etc/homeos/local-domain-root
	printf '%s\n' "$server_ip" >/etc/homeos/local-domain-ip

	cat >/etc/dnsmasq.d/homeos-local-domains.conf <<EOF
# HomeOS local wildcard DNS
# Point your router/LAN clients at this server for DNS, or add this server as a conditional DNS resolver.
address=/.${LOCAL_DOMAIN_ROOT}/${server_ip}
EOF

	if ! command -v dnsmasq >/dev/null 2>&1; then
		pkg_update
		pkg_install dnsmasq
	fi
	pkg_service_enable dnsmasq
	ok "Local wildcard DNS: *.${LOCAL_DOMAIN_ROOT} -> ${server_ip}"
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

	mkdir -p /etc/caddy/conf.d
	cat >/etc/caddy/Caddyfile <<EOF
{
  auto_https off
}

:80 {
  respond "HomeOS Server"
}

import /etc/caddy/conf.d/*.caddy
EOF

	if [[ -n "$CADDY_DOMAIN" ]]; then
		cat >/etc/caddy/Caddyfile <<EOF
{
  email admin@$CADDY_DOMAIN
}

$CADDY_DOMAIN {
  reverse_proxy localhost:81
}

import /etc/caddy/conf.d/*.caddy
EOF
	fi

	if [[ "$INSTALL_LOCAL_DOMAINS" == "yes" ]]; then
		cat >"/etc/caddy/conf.d/homeos.${LOCAL_DOMAIN_ROOT}.caddy" <<EOF
homeos.${LOCAL_DOMAIN_ROOT} {
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
		curl -fsSL https://repo.45drives.com/key/gpg.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg || warn "45Drives keyring setup failed (non-fatal)"
		curl -fsSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources || warn "45Drives repo setup failed (non-fatal)"
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
    # GPU acceleration (optional — Jellyfin starts even without /dev/dri)
    devices:
      - /dev/dri:/dev/dri
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
		curl -fsSL https://get.casaos.io | bash || warn "CasaOS install failed (non-fatal)"
	fi

	pkg_service_enable casaos 2>/dev/null || true
	ok "CasaOS on :81"
}

install_coolify() {
	[[ "$INSTALL_COOLIFY" == "yes" ]] || return 0
	section "Coolify"

	if [[ -d /data/coolify/source || -d /data/coolify ]]; then
		ok "Coolify already appears installed"
	else
		warn "Installing Coolify via official script..."
		curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash || warn "Coolify install failed (non-fatal)"
	fi

	if [[ "$INSTALL_LOCAL_DOMAINS" == "yes" && "$INSTALL_CADDY" == "yes" ]]; then
		mkdir -p /etc/caddy/conf.d
		cat >"/etc/caddy/conf.d/coolify.${LOCAL_DOMAIN_ROOT}.caddy" <<EOF
coolify.${LOCAL_DOMAIN_ROOT} {
  reverse_proxy localhost:8000
}
EOF
		if command -v caddy >/dev/null 2>&1; then
			caddy fmt --overwrite "/etc/caddy/conf.d/coolify.${LOCAL_DOMAIN_ROOT}.caddy" >/dev/null 2>&1 || true
			caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true
		fi
	fi

	ok "Coolify available on :8000 (and coolify.${LOCAL_DOMAIN_ROOT} when local domains are enabled)"
}

install_monitoring() {
	[[ "$INSTALL_MONITORING" == "yes" ]] || return 0
	section "Monitoring (Prometheus/Grafana)"

	local stack_dir="$HOMEOS_DATA_DIR/stacks/monitoring"
	mkdir -p "$stack_dir/provisioning/datasources" "$stack_dir/provisioning/dashboards" "$stack_dir/dashboards"

	local grafana_pass="$GRAFANA_ADMIN_PASSWORD" grafana_port="3000:3000"
	if [[ -z "$grafana_pass" ]]; then
		if [[ -f "$INSTALL_STATE_DIR/grafana-password.txt" && -s "$INSTALL_STATE_DIR/grafana-password.txt" ]]; then
			grafana_pass="$(cat "$INSTALL_STATE_DIR/grafana-password.txt")"
		else
			grafana_pass="$(generate_secret)"
			mkdir -p "$INSTALL_STATE_DIR"
			chmod 700 "$INSTALL_STATE_DIR"
			echo "$grafana_pass" >"$INSTALL_STATE_DIR/grafana-password.txt"
			chmod 600 "$INSTALL_STATE_DIR/grafana-password.txt"
			warn "Generated Grafana admin password. Retrieve with: sudo cat $INSTALL_STATE_DIR/grafana-password.txt"
		fi
	fi

	if [[ -n "$GRAFANA_BIND_ADDRESS" && "$GRAFANA_BIND_ADDRESS" != "0.0.0.0" && "$GRAFANA_BIND_ADDRESS" != "*" ]]; then
		grafana_port="${GRAFANA_BIND_ADDRESS}:3000:3000"
	fi

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
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    pid: host
    command:
      - '--path.rootfs=/host'
    volumes:
      - /:/host:ro,rslave
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "${grafana_port}"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${grafana_pass}
    volumes:
      - grafana-data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning:ro
      - ./dashboards:/var/lib/grafana/dashboards:ro
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
      - targets: ['node-exporter:9100']
EOF

	cat >"$stack_dir/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1
datasources:
  - name: HomeOS Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

	cat >"$stack_dir/provisioning/dashboards/homeos.yml" <<EOF
apiVersion: 1
providers:
  - name: HomeOS
    orgId: 1
    folder: HomeOS
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
EOF

	cat >"$stack_dir/dashboards/homeos-server.json" <<'EOF'
{
  "annotations": { "list": [] },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "panels": [
    {
      "datasource": "HomeOS Prometheus",
      "fieldConfig": { "defaults": { "unit": "percent", "thresholds": { "steps": [{ "color": "green", "value": null }, { "color": "yellow", "value": 70 }, { "color": "red", "value": 90 }] } }, "overrides": [] },
      "gridPos": { "h": 8, "w": 6, "x": 0, "y": 0 },
      "id": 1,
      "options": { "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false } },
      "targets": [{ "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)", "legendFormat": "CPU" }],
      "title": "CPU Usage",
      "type": "gauge"
    },
    {
      "datasource": "HomeOS Prometheus",
      "fieldConfig": { "defaults": { "unit": "percent", "thresholds": { "steps": [{ "color": "green", "value": null }, { "color": "yellow", "value": 75 }, { "color": "red", "value": 90 }] } }, "overrides": [] },
      "gridPos": { "h": 8, "w": 6, "x": 6, "y": 0 },
      "id": 2,
      "options": { "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false } },
      "targets": [{ "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100", "legendFormat": "RAM" }],
      "title": "Memory Usage",
      "type": "gauge"
    },
    {
      "datasource": "HomeOS Prometheus",
      "fieldConfig": { "defaults": { "unit": "percent" }, "overrides": [] },
      "gridPos": { "h": 8, "w": 6, "x": 12, "y": 0 },
      "id": 3,
      "targets": [{ "expr": "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} * 100) / node_filesystem_size_bytes{mountpoint=\"/\",fstype!~\"tmpfs|overlay\"})", "legendFormat": "Root disk" }],
      "title": "Disk Usage",
      "type": "timeseries"
    },
    {
      "datasource": "HomeOS Prometheus",
      "fieldConfig": { "defaults": { "unit": "Bps" }, "overrides": [] },
      "gridPos": { "h": 8, "w": 6, "x": 18, "y": 0 },
      "id": 4,
      "targets": [
        { "expr": "sum(rate(node_network_receive_bytes_total{device!~\"lo|veth.*|docker.*|br-.*\"}[5m]))", "legendFormat": "RX" },
        { "expr": "sum(rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|docker.*|br-.*\"}[5m]))", "legendFormat": "TX" }
      ],
      "title": "Network Throughput",
      "type": "timeseries"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 39,
  "tags": ["homeos"],
  "templating": { "list": [] },
  "time": { "from": "now-6h", "to": "now" },
  "timepicker": {},
  "timezone": "browser",
  "title": "HomeOS Server Overview",
  "uid": "homeos-server-overview",
  "version": 1,
  "weekStart": ""
}
EOF

	(cd "$stack_dir" && docker compose up -d) 2>/dev/null || warn "Monitoring stack start failed (docker daemon may not be running)"
	ok "Monitoring: Prometheus :9091, Grafana ${grafana_port}"
}

# ------------------------------------------------------------------------------
# SECTION: AI CLIS
# ------------------------------------------------------------------------------
install_ai_clis() {
	[[ "$INSTALL_AI_CLIS" == "yes" ]] || return 0
	section "AI CLIs"

	if ! command -v claude &>/dev/null; then
		npm install -g @anthropic-ai/claude-code 2>/dev/null || warn "claude-code install failed"
	fi

	if ! command -v codex &>/dev/null; then
		npm install -g @openai/codex 2>/dev/null || warn "codex install failed"
	fi

	if ! command -v gemini &>/dev/null; then
		npm install -g @google/gemini-cli 2>/dev/null || warn "gemini-cli install failed"
	fi

	if ! command -v cursor-agent &>/dev/null; then
		curl -fsSL https://cursor.com/install | bash 2>/dev/null || warn "cursor-agent install failed"
	fi

	if ! command -v kimi &>/dev/null; then
		curl -fsSL https://code.kimi.com/install.sh | bash 2>/dev/null || warn "kimi install failed"
	fi

	if ! command -v opencode &>/dev/null; then
		curl -fsSL https://opencode.ai/install | bash 2>/dev/null || warn "opencode install failed"
	fi

	local admin_rc="${HOMEOS_ADMIN_HOME}/.bashrc"
	[[ -f "${HOMEOS_ADMIN_HOME}/.zshrc" ]] && admin_rc="${HOMEOS_ADMIN_HOME}/.zshrc"

	if [[ -n "$ANTHROPIC_API_KEY" ]] && ! grep -q "ANTHROPIC_API_KEY=" "$admin_rc" 2>/dev/null; then
		echo "export ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" >>"$admin_rc"
	fi
	if [[ -n "$OPENAI_API_KEY" ]] && ! grep -q "OPENAI_API_KEY=" "$admin_rc" 2>/dev/null; then
		echo "export OPENAI_API_KEY=$OPENAI_API_KEY" >>"$admin_rc"
	fi
	if [[ -n "$GOOGLE_API_KEY" ]] && ! grep -q "GOOGLE_API_KEY=" "$admin_rc" 2>/dev/null; then
		echo "export GOOGLE_API_KEY=$GOOGLE_API_KEY" >>"$admin_rc"
	fi

	ok "AI CLIs installed"
}

install_pi() {
	[[ "$INSTALL_PI" == "yes" ]] || return 0
	section "Pi Coding Agent"

	if ! command -v npm >/dev/null 2>&1; then
		warn "npm not available; skipping Pi install"
		return 0
	fi

	if ! command -v pi >/dev/null 2>&1; then
		npm install -g @mariozechner/pi-coding-agent 2>/dev/null || warn "pi install failed"
	fi

	if command -v pi >/dev/null 2>&1; then
		local pkg
		while IFS= read -r pkg; do
			su - "$HOMEOS_ADMIN_USER" -c "pi install '$pkg'" >/dev/null 2>&1 || warn "Pi package install failed: $pkg"
		done < <(emit_words "$PI_PACKAGES")
		ok "Pi installed with configured packages"
	else
		warn "Pi command not available after install"
	fi
}

sanitize_ai_name() {
	local name="$1"
	name="${name##*/}"
	name="${name%.git}"
	name="${name//[^A-Za-z0-9._-]/-}"
	[[ -n "$name" ]] || return 1
	printf '%s\n' "$name"
}

emit_tokens() {
	printf '%s\n' "$1" | tr ', ' '\n\n' | sed '/^$/d'
}

emit_words() {
	printf '%s\n' "$1" | tr ' 	' '\n\n' | sed '/^$/d'
}

emit_records() {
	printf '%s\n' "$1" | tr ';' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d'
}

run_as_admin_array() {
	local quoted="" arg q
	for arg in "$@"; do
		printf -v q '%q' "$arg"
		quoted+="$q "
	done
	su - "$HOMEOS_ADMIN_USER" -c "$quoted"
}

normalize_skill_agent() {
	case "$1" in
	claude | claude_code | claude-code) printf '%s\n' "claude-code" ;;
	opencode | open-code) printf '%s\n' "opencode" ;;
	codex | pi | cursor) printf '%s\n' "$1" ;;
	kimi | kimi-cli) printf '%s\n' "kimi-cli" ;;
	gemini | gemini-cli) printf '%s\n' "gemini-cli" ;;
	*) printf '%s\n' "$1" ;;
	esac
}

list_has_token() {
	local list="$1" needle="$2" token
	while IFS= read -r token; do
		[[ "$token" == "$needle" ]] && return 0
	done < <(emit_tokens "$list")
	return 1
}

install_ai_skills() {
	[[ "$INSTALL_AI_SKILLS" == "yes" ]] || return 0
	[[ -n "$AI_SKILL_INSTALLS" && "$AI_SKILL_INSTALLS" != "none" ]] || return 0
	section "AI Skills (npx skills)"

	if ! command -v npx >/dev/null 2>&1; then
		warn "npx not available; skipping AI skills"
		return 0
	fi

	local entry source agents skills rest agent normalized skill installed_count=0
	while IFS= read -r entry; do
		source="${entry%%|*}"
		rest="${entry#*|}"
		if [[ "$rest" == "$entry" ]]; then
			agents="*"
			skills="*"
		else
			agents="${rest%%|*}"
			skills="${rest#*|}"
			[[ "$skills" != "$rest" ]] || skills="*"
		fi
		[[ -n "$source" ]] || continue

		local cmd=(npx --yes skills add "$source" -g -y --copy)
		cmd+=(-a)
		if [[ "$agents" == "*" || "$agents" == "all" ]]; then
			cmd+=("*")
		else
			while IFS= read -r agent; do
				if normalized="$(normalize_skill_agent "$agent")"; then
					cmd+=("$normalized")
				else
					warn "npx skills does not currently support agent '$agent'; skipping for $source"
				fi
			done < <(emit_tokens "$agents")
		fi
		cmd+=(-s)
		if [[ "$skills" == "*" || "$skills" == "all" ]]; then
			cmd+=("*")
		else
			while IFS= read -r skill; do cmd+=("$skill"); done < <(emit_tokens "$skills")
		fi

		if run_as_admin_array "${cmd[@]}" >/dev/null 2>&1; then
			installed_count=$((installed_count + 1))
			info "Installed skills from $source"
		else
			warn "Skill install failed: $source"
		fi
	done < <(emit_records "$AI_SKILL_INSTALLS")

	ok "AI skill package selections processed (${installed_count})"
}

ai_project_enabled() {
	local project="$1"
	[[ "$AI_PROJECTS" == "all" ]] && return 0
	list_has_token "$AI_PROJECTS" "$project"
}

ai_project_targets() {
	local project="$1" defaults="$2" override="" entry
	while IFS= read -r entry; do
		[[ "$entry" == *:* ]] || continue
		if [[ "${entry%%:*}" == "$project" ]]; then
			override="${entry#*:}"
			break
		fi
	done < <(emit_words "$AI_PROJECT_TARGETS")
	printf '%s\n' "${override:-$defaults}"
}

ai_target_allowed() {
	local target="$1"
	[[ "$target" == "shared" ]] && return 0
	[[ "$AI_PROJECT_TOOLS" == "all" ]] && return 0
	list_has_token "$AI_PROJECT_TOOLS" "$target"
}

ai_tool_root() {
	case "$1" in
	claude) printf '%s\n' "${HOMEOS_ADMIN_HOME}/.claude" ;;
	opencode) printf '%s\n' "${HOMEOS_ADMIN_HOME}/.config/opencode" ;;
	openagent) printf '%s\n' "${HOMEOS_ADMIN_HOME}/.config/openagent" ;;
	pi) printf '%s\n' "${HOMEOS_ADMIN_HOME}/.pi/agent" ;;
	codex) printf '%s\n' "${HOMEOS_ADMIN_HOME}/.codex" ;;
	cursor) printf '%s\n' "${HOMEOS_ADMIN_HOME}/.cursor" ;;
	gemini) printf '%s\n' "${HOMEOS_ADMIN_HOME}/.gemini" ;;
	*) return 1 ;;
	esac
}

link_tree_children() {
	local source_dir="$1" dest_dir="$2" prefix="$3" item base
	[[ -d "$source_dir" ]] || return 0
	mkdir -p "$dest_dir"
	shopt -s nullglob dotglob
	for item in "$source_dir"/*; do
		base="$(basename "$item")"
		[[ "$base" == "." || "$base" == ".." ]] && continue
		ln -sfn "$item" "${dest_dir}/${prefix}-${base}"
	done
	shopt -u nullglob dotglob
}

sync_ai_project_shared_content() {
	local project_dir="$1" project="$2" shared_root="$3"
	local skills_dir="${shared_root}/skills" agents_dir="${shared_root}/agents"
	mkdir -p "$skills_dir" "$agents_dir"

	if [[ -f "${project_dir}/SKILL.md" ]]; then
		ln -sfn "$project_dir" "${skills_dir}/${project}"
	fi
	link_tree_children "${project_dir}/skills" "$skills_dir" "$project"
	link_tree_children "${project_dir}/.claude/skills" "$skills_dir" "$project"
	link_tree_children "${project_dir}/agents" "$agents_dir" "$project"
	link_tree_children "${project_dir}/.claude/agents" "$agents_dir" "$project"
	link_tree_children "${project_dir}/.agents" "$agents_dir" "$project"
}

install_ai_tool_links() {
	local tool="$1" project="$2" project_dir="$3" shared_root="$4" root
	root="$(ai_tool_root "$tool")" || {
		warn "Unknown AI tool target '$tool' for $project"
		return 0
	}

	mkdir -p "$root/homeos/projects" "$root/homeos/mcp/${project}" "$root/homeos/plugins/${project}" "$root/skills" "$root/agents"
	ln -sfn "$project_dir" "$root/homeos/projects/$project"
	ln -sfn "${shared_root}/skills" "$root/homeos/skills"
	ln -sfn "${shared_root}/agents" "$root/homeos/agents"
	ln -sfn "${shared_root}/skills" "$root/skills/homeos-shared"
	ln -sfn "${shared_root}/agents" "$root/agents/homeos-shared"
	cat >"$root/homeos/README.md" <<EOF
# HomeOS AI tool integration: ${tool}

Projects linked here are selected for ${tool}. Shared skills and agents are symlinked from ${shared_root}.

MCP servers and plugins are intentionally contained under this tool's own homeos/mcp and homeos/plugins directories. HomeOS does not edit global MCP server configuration files, so existing MCP behavior is preserved.
EOF
}

materialize_ai_project() {
	local project="$1" repo="$2" project_dir="$3"
	mkdir -p "$(dirname "$project_dir")"
	if [[ "$AI_PROJECT_INSTALL_MODE" == "manifest-only" ]]; then
		mkdir -p "$project_dir"
		printf '%s\n' "$repo" >"$project_dir/REPOSITORY_URL"
		return 0
	fi

	if [[ -d "$project_dir/.git" ]]; then
		git -C "$project_dir" pull --ff-only --quiet || warn "AI project update failed: $project"
	elif [[ -e "$project_dir" ]]; then
		warn "AI project path exists and is not a git repo: $project_dir"
	else
		git clone --quiet --depth 1 "$repo" "$project_dir" || {
			warn "AI project clone failed: $project"
			mkdir -p "$project_dir"
			printf '%s\n' "$repo" >"$project_dir/REPOSITORY_URL"
		}
	fi
}

install_ai_projects() {
	[[ "$INSTALL_AI_PROJECTS" == "yes" ]] || return 0
	section "AI Project Library"

	if [[ "$AI_PROJECT_INSTALL_MODE" != "clone" && "$AI_PROJECT_INSTALL_MODE" != "manifest-only" ]]; then
		warn "Unknown AI_PROJECT_INSTALL_MODE=$AI_PROJECT_INSTALL_MODE; using clone"
		AI_PROJECT_INSTALL_MODE="clone"
	fi

	local ai_root="${HOMEOS_DATA_DIR}/ai"
	local projects_root="${ai_root}/projects" shared_root="${ai_root}/shared"
	mkdir -p "$projects_root" "${shared_root}/skills" "${shared_root}/agents"

	local -a project_names=(
		oh-my-claudecode claude-mem A11Y.md code-review-graph hindsight taste-skill portless skills
		cinsights claude-context ClawTeam heretic OpenViking impeccable agency-agents oh-my-openagent
		shannon hive superpowers AgentTower
	)
	declare -A project_urls=(
		["oh-my-claudecode"]="https://github.com/yeachan-heo/oh-my-claudecode.git"
		["claude-mem"]="https://github.com/thedotmack/claude-mem.git"
		["A11Y.md"]="https://github.com/fecarrico/A11Y.md.git"
		["code-review-graph"]="https://github.com/tirth8205/code-review-graph.git"
		["hindsight"]="https://github.com/vectorize-io/hindsight.git"
		["taste-skill"]="https://github.com/Leonxlnx/taste-skill.git"
		["portless"]="https://github.com/vercel-labs/portless.git"
		["skills"]="https://github.com/mattpocock/skills.git"
		["cinsights"]="https://github.com/deepankarm/cinsights.git"
		["claude-context"]="https://github.com/zilliztech/claude-context.git"
		["ClawTeam"]="https://github.com/HKUDS/ClawTeam.git"
		["heretic"]="https://github.com/p-e-w/heretic.git"
		["OpenViking"]="https://github.com/volcengine/OpenViking.git"
		["impeccable"]="https://github.com/pbakaus/impeccable.git"
		["agency-agents"]="https://github.com/msitarzewski/agency-agents.git"
		["oh-my-openagent"]="https://github.com/code-yeongyu/oh-my-openagent.git"
		["shannon"]="https://github.com/KeygraphHQ/shannon.git"
		["hive"]="https://github.com/aden-hive/hive.git"
		["superpowers"]="https://github.com/obra/superpowers.git"
		["AgentTower"]="https://github.com/opensoft/AgentTower.git"
	)
	declare -A project_defaults=(
		["oh-my-claudecode"]="claude,shared"
		["claude-mem"]="claude,shared"
		["A11Y.md"]="shared,claude,opencode,pi,codex,cursor,gemini"
		["code-review-graph"]="shared,claude,opencode,pi,codex,cursor,gemini"
		["hindsight"]="shared,claude,opencode,pi,codex,cursor,gemini"
		["taste-skill"]="shared,claude,opencode,pi,codex,cursor"
		["portless"]="shared,claude,opencode,pi,codex,cursor,gemini"
		["skills"]="shared,claude,opencode,pi,codex,cursor,gemini"
		["cinsights"]="shared,claude,opencode,pi,codex,cursor,gemini"
		["claude-context"]="claude,shared"
		["ClawTeam"]="claude,shared"
		["heretic"]="shared,claude,opencode,pi,codex,cursor"
		["OpenViking"]="shared,opencode,openagent,claude"
		["impeccable"]="shared,claude,opencode,cursor"
		["agency-agents"]="shared,claude,opencode,pi"
		["oh-my-openagent"]="openagent,shared"
		["shannon"]="shared,claude,opencode,pi,codex"
		["hive"]="shared,claude,opencode,pi,codex,cursor"
		["superpowers"]="shared,claude,opencode,pi,codex,cursor,gemini"
		["AgentTower"]="shared,opencode,openagent,claude"
	)

	local project repo safe_name project_dir targets target linked_count=0
	printf '# project\trepo\ttargets\n' >"${ai_root}/manifest.tsv"
	for project in "${project_names[@]}"; do
		ai_project_enabled "$project" || continue
		repo="${project_urls[$project]}"
		safe_name="$(sanitize_ai_name "$project")"
		project_dir="${projects_root}/${safe_name}"
		targets="$(ai_project_targets "$project" "${project_defaults[$project]}")"

		materialize_ai_project "$project" "$repo" "$project_dir"
		sync_ai_project_shared_content "$project_dir" "$safe_name" "$shared_root"
		printf '%s\t%s\t%s\n' "$project" "$repo" "$targets" >>"${ai_root}/manifest.tsv"

		while IFS= read -r target; do
			ai_target_allowed "$target" || continue
			[[ "$target" == "shared" ]] && continue
			install_ai_tool_links "$target" "$safe_name" "$project_dir" "$shared_root"
		done < <(emit_tokens "$targets")
		linked_count=$((linked_count + 1))
	done

	cat >"${ai_root}/README.md" <<EOF
# HomeOS AI project library

Projects live under: ${projects_root}
Shared skills live under: ${shared_root}/skills
Shared agents live under: ${shared_root}/agents

Per-tool integrations are isolated in each tool's own HomeOS namespace. Shared skills/agents are symlinked; MCP servers and plugins are not copied across tools. HomeOS does not edit global MCP server configuration files and does not rewrite MCP server config files.

Customize with:
- AI_PROJECTS="all" or a space/comma-separated project list
- AI_PROJECT_TOOLS="claude,opencode,openagent,pi,codex,cursor,gemini" or "all"
- AI_PROJECT_TARGETS="project:tool1,tool2 other-project:shared,claude"
- AI_PROJECT_INSTALL_MODE="clone" or "manifest-only"
EOF
	if id -u "$HOMEOS_ADMIN_USER" >/dev/null 2>&1; then
		chown -R "$HOMEOS_ADMIN_USER:$HOMEOS_ADMIN_USER" "$ai_root" "$HOMEOS_ADMIN_HOME/.claude" "$HOMEOS_ADMIN_HOME/.config" "$HOMEOS_ADMIN_HOME/.pi" "$HOMEOS_ADMIN_HOME/.codex" "$HOMEOS_ADMIN_HOME/.cursor" "$HOMEOS_ADMIN_HOME/.gemini" 2>/dev/null || true
	fi
	ok "AI project library ready (${linked_count} projects): ${ai_root}"
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

		if [[ "$GITHUB_TOOLS" != "all" && ! " $GITHUB_TOOLS " =~ $name ]]; then
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

	local tcp_ports=(22 53 80 443 445 139 2049 8000 8123 8096 9090 81 8222 3000 9091)
	local udp_ports=(53 137 138 2049 5353 1900 7359)

	for p in $EXTRA_TCP_PORTS; do tcp_ports+=("$p"); done
	for p in $EXTRA_UDP_PORTS; do udp_ports+=("$p"); done

	if [[ "$OS_FAMILY" == "debian" ]]; then
		ufw default deny incoming || warn "ufw default deny failed (may be container)"
		ufw default allow outgoing || warn "ufw default allow failed (may be container)"
		for p in "${tcp_ports[@]}"; do ufw allow "$p"/tcp || warn "ufw allow $p/tcp failed"; done
		for p in "${udp_ports[@]}"; do ufw allow "$p"/udp || warn "ufw allow $p/udp failed"; done
		ufw allow in on tailscale0 2>/dev/null || true
		ufw --force enable || warn "ufw enable failed (may be container without iptables/netfilter)"
	else
		if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null; then
			systemctl enable --now firewalld 2>/dev/null || true
		else
			warn "systemd not running; skipping firewalld enable"
		fi
		for p in "${tcp_ports[@]}"; do firewall-cmd --permanent --add-port="$p"/tcp || warn "firewall-cmd add-port $p/tcp failed"; done
		for p in "${udp_ports[@]}"; do firewall-cmd --permanent --add-port="$p"/udp || warn "firewall-cmd add-port $p/udp failed"; done
		firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
		firewall-cmd --reload || warn "firewall-cmd reload failed"
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

	if [[ -f "${HOMEOS_ADMIN_HOME}/.ssh/authorized_keys" ]] && [[ -s "${HOMEOS_ADMIN_HOME}/.ssh/authorized_keys" ]]; then
		sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/99-homeos.conf
	fi

	if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null; then
		systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || warn "Could not restart SSH service"
	else
		warn "systemd not running; SSH config written but not reloaded"
	fi
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

	mkdir -p /etc/homeos
	cat >/etc/homeos/backup.env <<EOF
# HomeOS Backup Configuration
BACKUP_TARGET=${BACKUP_TARGET:-}
BACKUP_SCHEDULE=daily
BACKUP_KEEP_DAILY=7
BACKUP_KEEP_WEEKLY=4
BACKUP_KEEP_MONTHLY=12
EOF

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
# SECTION: UNINSTALL
# ------------------------------------------------------------------------------
purge_homeos_packages() {
	[[ "$UNINSTALL_PURGE_PACKAGES" == "yes" ]] || return 0

	local ans=""
	if [[ "$YES_FLAG" == "yes" ]]; then
		ans="yes"
	elif [[ "$HOMEOS_UNATTENDED" == "yes" ]]; then
		ans="no"
	else
		read -r -p "Also remove HomeOS-installed packages and repositories? [y/N] " ans
	fi

	if [[ "${ans,,}" != "y" && "${ans,,}" != "yes" ]]; then
		warn "Package/repository purge skipped. Re-run with --yes --purge to confirm."
		return 0
	fi

	log "Removing HomeOS package repositories..."
	if [[ "$OS_FAMILY" == "debian" ]]; then
		rm -f \
			/etc/apt/sources.list.d/docker.list \
			/etc/apt/sources.list.d/caddy.list \
			/etc/apt/sources.list.d/nodesource.list \
			/etc/apt/sources.list.d/nodesource.sources \
			/etc/apt/sources.list.d/tailscale.list \
			/etc/apt/sources.list.d/45drives.sources
		rm -f \
			/etc/apt/keyrings/docker.asc \
			/etc/apt/keyrings/caddy.asc \
			/usr/share/keyrings/nodesource.gpg \
			/usr/share/keyrings/tailscale-archive-keyring.gpg \
			/usr/share/keyrings/45drives-archive-keyring.gpg
		pkg_remove_if_installed \
			docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
			nodejs tailscale tailscale-archive-keyring caddy casaos dnsmasq \
			cockpit cockpit-ws cockpit-system cockpit-bridge cockpit-storaged cockpit-packagekit \
			restic prometheus-node-exporter
	else
		rm -f \
			/etc/yum.repos.d/docker-ce.repo \
			/etc/yum.repos.d/tailscale.repo \
			/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:group_caddy:caddy.repo
		pkg_remove_if_installed \
			docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
			nodejs npm tailscale caddy casaos dnsmasq cockpit cockpit-ws cockpit-system restic
	fi
}

uninstall_homeos() {
	section "Uninstalling HomeOS"

	local ans=""
	if [[ "$YES_FLAG" == "yes" || "$HOMEOS_UNATTENDED" == "yes" ]]; then
		ans="yes"
	else
		read -r -p "Remove all HomeOS components? [y/N] " ans
	fi
	[[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || die "Aborted."

	if command -v docker &>/dev/null; then
		log "Stopping HomeOS containers..."
		for stack_dir in "$HOMEOS_DATA_DIR/stacks/"*/; do
			if [[ -f "$stack_dir/docker-compose.yml" ]]; then
				(cd "$stack_dir" && docker compose down 2>/dev/null) || true
			fi
		done
	fi

	local vol_ans=""
	if [[ "$YES_FLAG" == "yes" ]]; then
		vol_ans="yes"
	elif [[ "$HOMEOS_UNATTENDED" == "yes" ]]; then
		vol_ans="no"
	else
		read -r -p "Remove Docker volumes (data will be lost)? [y/N] " vol_ans
	fi
	if [[ "${vol_ans,,}" == "y" || "${vol_ans,,}" == "yes" ]]; then
		if command -v docker &>/dev/null; then
			docker volume rm ha-config jellyfin-config jellyfin-cache vw-data prom-data grafana-data 2>/dev/null || true
		fi
	fi

	if command -v systemctl &>/dev/null; then
		systemctl disable --now cockpit.socket caddy casaos 2>/dev/null || true
	fi

	rm -rf "$HOMEOS_DATA_DIR"
	rm -rf /etc/homeos
	rm -f /etc/cron.daily/homeos-backup
	rm -f /etc/dnsmasq.d/homeos-local-domains.conf
	rm -f /etc/caddy/conf.d/*.homeos.home.arpa.caddy /etc/caddy/conf.d/homeos.*.caddy /etc/caddy/conf.d/coolify.*.caddy 2>/dev/null || true
	rm -f /usr/local/bin/homeos
	rm -f /etc/ssh/sshd_config.d/99-homeos.conf
	rm -f "/etc/sudoers.d/${HOMEOS_ADMIN_USER}"
	rm -f /etc/apt/sources.list.d/45drives.sources /usr/share/keyrings/45drives-archive-keyring.gpg
	if [[ -f /etc/caddy/Caddyfile ]] && grep -Eq 'HomeOS Server|reverse_proxy localhost:81' /etc/caddy/Caddyfile; then
		rm -f /etc/caddy/Caddyfile
	fi
	if [[ -f /etc/docker/daemon.json ]] && grep -q 'default-address-pools' /etc/docker/daemon.json && grep -q "$DOCKER_NETWORK_RANGE" /etc/docker/daemon.json; then
		rm -f /etc/docker/daemon.json
	fi

	purge_homeos_packages
	rm -rf "$INSTALL_STATE_DIR"

	if [[ "$UNINSTALL_PURGE_PACKAGES" == "yes" ]]; then
		ok "HomeOS uninstalled. Package purge was requested; see warnings above for anything preserved."
	else
		ok "HomeOS uninstalled. Docker, Node.js, and system packages were not removed."
		info "To remove packages too: sudo ./install.sh uninstall --purge --yes"
	fi
}

# ------------------------------------------------------------------------------
# SECTION: HOMEOS CLI
# ------------------------------------------------------------------------------
install_homeos_cli() {
	[[ "$INSTALL_BASE" == "yes" ]] || return 0
	section "HomeOS CLI"

	cat >/usr/local/bin/homeos <<'CLIEOF'
#!/usr/bin/env bash
# HomeOS day-2 CLI v1.2.0
set -euo pipefail

ADMIN_USER="${HOMEOS_ADMIN_USER:-admin}"
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6 || echo /home/$ADMIN_USER)"
DATA_DIR="${HOMEOS_DATA_DIR:-/opt/homeos}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

show_status() {
	local pretty="unknown" uptime_text="unavailable"
	bold "== HomeOS Status =="
	pretty="$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"' || true)"
	[[ -n "$pretty" ]] || pretty="unknown"
	if command -v uptime >/dev/null 2>&1; then
		uptime_text="$(uptime -p 2>/dev/null || uptime 2>/dev/null || true)"
		[[ -n "$uptime_text" ]] || uptime_text="unavailable"
	fi
	echo "OS: $pretty"
	echo "Uptime: $uptime_text"
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
}

show_doctor() {
	local fails=0
	check() {
		local label="$1"; shift
		if "$@" >/dev/null 2>&1; then printf "  \033[32m✓\033[0m %s\n" "$label"
		else printf "  \033[31m✗\033[0m %s\n" "$label"; fails=$((fails+1)); fi
	}
	bold "== Runtime =="
	check "node" bash -c 'node -v | grep -q "^v"'
	check "docker" docker --version
	check "docker compose" docker compose version
	bold "== Services =="
	check "tailscaled" systemctl is-active tailscaled
	check "cockpit" systemctl is-active cockpit.socket
	bold "== Stacks =="
	check "homeassistant :8123" bash -c 'curl -fsSL --max-time 3 http://localhost:8123 >/dev/null 2>&1'
	check "jellyfin :8096" bash -c 'curl -fsSL --max-time 3 http://localhost:8096 >/dev/null 2>&1'
	check "vaultwarden :8222" bash -c 'curl -fsSL --max-time 3 http://localhost:8222 >/dev/null 2>&1'
	check "grafana :3000" bash -c 'curl -fsSL --max-time 3 http://localhost:3000 >/dev/null 2>&1'
	bold "== Disk =="
	df -h / /opt /srv 2>/dev/null | grep -v Filesystem || true
	echo
	if [[ "$fails" -eq 0 ]]; then bold "ALL OK"
	else bold "$fails check(s) failed"; exit 1; fi
}

show_logs() {
	local svc="${1:-}"
	if [[ -z "$svc" ]]; then
		echo "Usage: homeos logs <service>"
		echo "Services: homeassistant, jellyfin, vaultwarden, prometheus, grafana, watchtower"
		exit 1
	fi
	if [[ -f "$DATA_DIR/stacks/$svc/docker-compose.yml" ]]; then
		docker compose -f "$DATA_DIR/stacks/$svc/docker-compose.yml" logs -f
	else
		docker logs -f "$svc" 2>/dev/null || echo "Service '$svc' not found"
	fi
}

do_restart() {
	local svc="${1:-}"
	if [[ -z "$svc" ]]; then
		echo "Usage: homeos restart <service>"
		echo "Services: homeassistant, jellyfin, vaultwarden, prometheus, grafana, watchtower"
		exit 1
	fi
	if [[ -f "$DATA_DIR/stacks/$svc/docker-compose.yml" ]]; then
		docker compose -f "$DATA_DIR/stacks/$svc/docker-compose.yml" restart
		echo "Restarted $svc"
	else
		docker restart "$svc" 2>/dev/null || echo "Service '$svc' not found"
	fi
}

do_backup() {
	if [[ -x /etc/cron.daily/homeos-backup ]]; then
		sudo /etc/cron.daily/homeos-backup
	else
		echo "Backup script not configured. Set BACKUP_TARGET in /etc/homeos/homeos.conf"
		exit 1
	fi
}

show_config() {
	if [[ -f /etc/homeos/homeos.conf ]]; then
		cat /etc/homeos/homeos.conf
	else
		echo "No config file at /etc/homeos/homeos.conf"
		exit 1
	fi
}

local_domain_root() { cat /etc/homeos/local-domain-root 2>/dev/null || printf 'homeos.home.arpa\n'; }

sanitize_domain_label() {
	local label="$1"
	label="${label,,}"
	label="${label//[^a-z0-9-]/-}"
	label="${label#-}"
	label="${label%-}"
	[[ -n "$label" ]] || return 1
	printf '%s\n' "$label"
}

do_domain() {
	local action="${1:-list}" root name port upstream file
	root="$(local_domain_root)"
	case "$action" in
	add)
		name="$(sanitize_domain_label "${2:-}")" || { echo "Usage: homeos domain add <name> <port> [upstream-host]"; exit 1; }
		port="${3:-}"; upstream="${4:-localhost}"
		[[ "$port" =~ ^[0-9]+$ ]] || { echo "Port must be numeric"; exit 1; }
		mkdir -p /etc/caddy/conf.d
		file="/etc/caddy/conf.d/${name}.${root}.caddy"
		cat >"$file" <<EOF_DOMAIN
${name}.${root} {
  reverse_proxy ${upstream}:${port}
}
EOF_DOMAIN
		caddy fmt --overwrite "$file" >/dev/null 2>&1 || true
		caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true
		echo "Local route ready: http://${name}.${root} -> ${upstream}:${port}"
		;;
	remove | rm)
		name="$(sanitize_domain_label "${2:-}")" || { echo "Usage: homeos domain remove <name>"; exit 1; }
		rm -f "/etc/caddy/conf.d/${name}.${root}.caddy"
		caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true
		echo "Removed ${name}.${root}"
		;;
	list | ls)
		find /etc/caddy/conf.d -maxdepth 1 -name "*.${root}.caddy" -print 2>/dev/null | sed -E "s#.*/([^/]+)\\.caddy#\\1#" | sort || true
		;;
	*) echo "Usage: homeos domain {add|remove|list}"; exit 1 ;;
	esac
}

download_installer() {
	curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/universal-installer/install.sh -o /tmp/homeos-install.sh || {
		echo "Failed to download installer"
		exit 1
	}
}

do_uninstall() {
	echo "Pulling latest HomeOS installer..."
	download_installer
	sudo bash /tmp/homeos-install.sh uninstall "$@"
}

do_update() {
	echo "Pulling latest HomeOS installer..."
	download_installer
	local args=(--unattended) cfg=""
	if [[ -f /var/lib/homeos/config-path ]]; then
		cfg="$(cat /var/lib/homeos/config-path)"
	fi
	if [[ -n "$cfg" && -f "$cfg" ]]; then
		args+=(--config "$cfg")
	elif [[ -f /etc/homeos/homeos.conf ]]; then
		args+=(--config /etc/homeos/homeos.conf)
	fi
	sudo bash /tmp/homeos-install.sh "${args[@]}"
}

case "${1:-status}" in
	status) show_status ;;
	doctor) show_doctor ;;
	logs) shift || true; show_logs "$@" ;;
	restart) shift || true; do_restart "$@" ;;
	backup) do_backup ;;
	config) show_config ;;
	domain) shift || true; do_domain "$@" ;;
	uninstall) shift || true; do_uninstall "$@" ;;
	update) do_update ;;
	--version|-v) echo "HomeOS CLI v1.2.0" ;;
	*) echo "Usage: homeos {status|doctor|logs|restart|backup|config|domain|update|uninstall|--version}"; exit 1 ;;
esac
CLIEOF

	chmod +x /usr/local/bin/homeos

	echo "homeos_cli=$(date -u +%FT%TZ)" >>"$INSTALL_STATE_DIR/install.state" 2>/dev/null || true

	ok "HomeOS CLI installed. Run: homeos status"
}

# ------------------------------------------------------------------------------
# WATCHTOWER
# ------------------------------------------------------------------------------
install_watchtower() {
	[[ "$INSTALL_DOCKER" == "yes" ]] || return 0
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
    command: --interval 86400 --cleanup
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
	local primary_ip
	primary_ip="$(get_primary_ip)"
	[[ "$INSTALL_LOCAL_DOMAINS" == "yes" ]] && echo "  Local domains: *.${LOCAL_DOMAIN_ROOT} -> ${primary_ip} (set router DNS to this server)"
	[[ "$INSTALL_COOLIFY" == "yes" ]] && echo "  Coolify:       http://${primary_ip}:8000 / http://coolify.${LOCAL_DOMAIN_ROOT}"
	[[ "$INSTALL_CASAOS" == "yes" ]] && echo "  CasaOS:        http://${primary_ip}:81"
	[[ "$INSTALL_HOMEASSISTANT" == "yes" ]] && echo "  Home Assistant: http://${primary_ip}:8123"
	[[ "$INSTALL_JELLYFIN" == "yes" ]] && echo "  Jellyfin:      http://${primary_ip}:8096"
	[[ "$INSTALL_COCKPIT" == "yes" ]] && echo "  Cockpit:       https://${primary_ip}:9090"
	[[ "$INSTALL_VAULTWARDEN" == "yes" ]] && echo "  Vaultwarden:   http://${primary_ip}:8222"
	if [[ "$INSTALL_MONITORING" == "yes" ]]; then
		local grafana_host="$primary_ip"
		[[ -n "$GRAFANA_BIND_ADDRESS" && "$GRAFANA_BIND_ADDRESS" != "0.0.0.0" && "$GRAFANA_BIND_ADDRESS" != "*" ]] && grafana_host="$GRAFANA_BIND_ADDRESS"
		echo "  Grafana:       http://${grafana_host}:3000"
	fi
	echo
	echo -e "${BOLD}Management:${RESET}"
	echo "  homeos status   - Show system status"
	echo "  homeos doctor   - Run health checks"
	echo "  homeos logs     - View container logs"
	echo "  homeos restart  - Restart a service"
	echo "  homeos backup   - Trigger backup"
	echo "  homeos config   - Show configuration"
	echo "  homeos domain   - Manage local app/site domains"
	echo "  homeos update   - Update HomeOS"
	echo
	echo -e "${YELLOW}SSH Access:${RESET}"
	echo "  ssh $HOMEOS_ADMIN_USER@${primary_ip}"
	echo
	if [[ "$HOMEOS_UNATTENDED" == "yes" ]]; then
		echo -e "${YELLOW}Note:${RESET} Unattended mode: random password generated. Retrieve with: sudo cat $INSTALL_STATE_DIR/admin-password.txt"
	else
		echo -e "${YELLOW}Note:${RESET} Default password is '${HOMEOS_ADMIN_USER}' (forced change on first login)"
	fi
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
		--dry-run)
			DRY_RUN="yes"
			shift
			;;
		--skip-checks)
			SKIP_CHECKS="yes"
			shift
			;;
		--yes)
			YES_FLAG="yes"
			shift
			;;
		--purge | --purge-packages | --full)
			UNINSTALL_PURGE_PACKAGES="yes"
			shift
			;;
		uninstall)
			COMMAND="uninstall"
			shift
			;;
		--version | -v)
			echo "HomeOS Universal Installer v${HI_VERSION}"
			exit 0
			;;
		--help | -h)
			cat <<HELP
HomeOS Universal Installer v${HI_VERSION}

Usage: sudo $0 [OPTIONS] [uninstall]

Options:
  --config <path>      Path to config file
  --unattended         Non-interactive mode (requires config)
  --mode <full|minimal> Installation mode
  --dry-run            Show what would be installed without making changes
  --skip-checks        Skip pre-flight checks
  --yes                Auto-accept prompts and skip checklist UI in interactive mode
  --purge              With uninstall, also remove installed packages/repos
  --version            Show version
  --help               Show this help

Commands:
  (no command)         Run installer
  uninstall            Remove HomeOS

Interactive mode:
  If whiptail is available, HomeOS shows checklists for components, AI skill
  packages, and target agents. Move the highlight over any item to see help for
  what it installs and what to consider before enabling it.

Examples:
  sudo $0                                    # Interactive install
  sudo $0 --config /etc/homeos/homeos.conf   # Use custom config
  sudo $0 --unattended --mode minimal        # Unattended minimal
  sudo $0 --dry-run                          # Preview installation
  sudo $0 uninstall                          # Remove HomeOS data/config only
  sudo $0 uninstall --purge --yes            # Remove HomeOS plus packages/repos

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

	mkdir -p "$(dirname "$LOG_FILE")"
	: >"$LOG_FILE"

	log "HomeOS Universal Installer v${HI_VERSION}"
	detect_os
	load_config

	# Ensure state directory exists for tracking
	mkdir -p "$INSTALL_STATE_DIR" 2>/dev/null || true

	if [[ "$COMMAND" == "uninstall" ]]; then
		uninstall_homeos
		exit 0
	fi

	if [[ "$HOMEOS_MODE" == "minimal" ]]; then
		INSTALL_COOLIFY="no"
		INSTALL_CASAOS="no"
		INSTALL_HOMEASSISTANT="no"
		INSTALL_JELLYFIN="no"
		INSTALL_VAULTWARDEN="no"
		INSTALL_AI_CLIS="no"
		INSTALL_PI="no"
		INSTALL_AI_SKILLS="no"
		INSTALL_AI_PROJECTS="no"
		INSTALL_GITHUB_TOOLS="no"
		INSTALL_MONITORING="no"
		INSTALL_BACKUPS="no"
	fi

	confirm_install
	preflight_checks

	log "Starting installation..."
	log_to_file "INSTALL START mode=$HOMEOS_MODE os=$OS_ID $OS_VERSION"

	if [[ "$DRY_RUN" == "yes" ]]; then
		section "Dry Run Preview"
		info "OS: $OS_ID $OS_VERSION ($OS_FAMILY)"
		info "Mode: $HOMEOS_MODE"
		info "Admin: $HOMEOS_ADMIN_USER"
		info ""
		info "Components that would be installed:"
		[[ "$INSTALL_BASE" == "yes" ]] && info "  - Base system (packages, user, directories)"
		[[ "$INSTALL_DOCKER" == "yes" ]] && info "  - Docker CE + Compose"
		[[ "$INSTALL_NODE" == "yes" ]] && info "  - Node.js 24 + pnpm + Bun"
		[[ "$INSTALL_TAILSCALE" == "yes" ]] && info "  - Tailscale VPN"
		[[ "$INSTALL_CADDY" == "yes" ]] && info "  - Caddy reverse proxy"
		[[ "$INSTALL_LOCAL_DOMAINS" == "yes" ]] && info "  - Local custom domains (*.${LOCAL_DOMAIN_ROOT})"
		[[ "$INSTALL_COOLIFY" == "yes" ]] && info "  - Coolify app platform (:8000)"
		[[ "$INSTALL_COCKPIT" == "yes" ]] && info "  - Cockpit + file sharing"
		[[ "$INSTALL_CASAOS" == "yes" ]] && info "  - CasaOS"
		[[ "$INSTALL_HOMEASSISTANT" == "yes" ]] && info "  - Home Assistant (:8123)"
		[[ "$INSTALL_JELLYFIN" == "yes" ]] && info "  - Jellyfin (:8096)"
		[[ "$INSTALL_VAULTWARDEN" == "yes" ]] && info "  - Vaultwarden (:8222)"
		[[ "$INSTALL_AI_CLIS" == "yes" ]] && info "  - AI CLIs"
		[[ "$INSTALL_PI" == "yes" ]] && info "  - Pi coding agent + packages"
		[[ "$INSTALL_AI_SKILLS" == "yes" ]] && info "  - Selectable npx skills"
		[[ "$INSTALL_AI_PROJECTS" == "yes" ]] && info "  - AI project library (${AI_PROJECTS} -> ${AI_PROJECT_TOOLS})"
		[[ "$INSTALL_GITHUB_TOOLS" == "yes" ]] && info "  - GitHub dev tools"
		[[ "$INSTALL_MONITORING" == "yes" ]] && info "  - Prometheus (:9091) + Grafana (:3000)"
		[[ "$INSTALL_BACKUPS" == "yes" ]] && info "  - Backups (restic)"
		[[ "$INSTALL_FIREWALL" == "yes" ]] && info "  - Firewall (UFW/firewalld)"
		[[ "$INSTALL_SSH_HARDEN" == "yes" ]] && info "  - SSH hardening"
		info ""
		ok "Dry run complete. No changes made."
		exit 0
	fi

	if [[ -n "$CONFIG_FILE" ]]; then
		printf '%s\n' "$CONFIG_FILE" >"$INSTALL_STATE_DIR/config-path" 2>/dev/null || true
		chmod 600 "$INSTALL_STATE_DIR/config-path" 2>/dev/null || true
	fi

	install_base
	install_docker
	install_node
	install_tailscale
	install_local_domains
	install_caddy
	install_coolify
	install_cockpit
	install_casaos
	install_homeassistant
	install_jellyfin
	install_vaultwarden
	install_monitoring
	install_watchtower
	install_ai_clis
	install_pi
	install_ai_skills
	install_ai_projects
	install_github_tools
	install_backups
	install_firewall
	install_ssh_harden
	install_homeos_cli

	log_to_file "INSTALL COMPLETE"
	print_summary

	if command -v homeos &>/dev/null; then
		section "Post-Install Health Check"
		homeos doctor 2>/dev/null || warn "Some health checks failed. Review output above."
	fi
}

main "$@"
