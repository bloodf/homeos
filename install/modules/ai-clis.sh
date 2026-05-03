#!/usr/bin/env bash
[[ -n "${__HI_MOD_AI:-}" ]] && return 0
__HI_MOD_AI=1

feature_id="ai-clis"
feature_name="AI CLIs (claude, codex, gemini)"
feature_category="AI/dev tools"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="low"

detect() {
  command -v claude >/dev/null 2>&1 || command -v codex >/dev/null 2>&1 || command -v gemini >/dev/null 2>&1
}

plan() { echo "Install AI CLIs via existing 'ai-clis' ansible role"; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role ai-clis
    return 0
  fi

  # Standalone: install Node.js + npm CLIs directly
  ui::info "ai-clis: installing via standalone path (no ansible)..."

  # Ensure Node.js is available
  if ! command -v node >/dev/null 2>&1; then
    case "${DISTRO_FAMILY:-}" in
      debian)
        pkg_install ca-certificates curl gnupg
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.asc
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_24.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
        pkg_update
        pkg_install nodejs
        ;;
      rhel)
        pkg_install nodejs npm || { ui::error "Node.js not available"; return 1; }
        ;;
    esac
  fi

  # Install corepack + pnpm
  corepack enable 2>/dev/null || true
  corepack prepare pnpm@latest --activate 2>/dev/null || true

  # Install npm-based AI CLIs
  npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli 2>/dev/null || true

  # Install cursor-agent via curl
  if ! command -v cursor-agent >/dev/null 2>&1; then
    curl -fsSL https://cursor.com/install | bash 2>/dev/null || true
  fi

  # Install kimi via curl
  if ! command -v kimi >/dev/null 2>&1; then
    curl -fsSL https://code.kimi.com/install.sh | bash 2>/dev/null || true
  fi

  ui::ok "ai-clis: standalone install attempted (some CLIs may require manual setup)"
}

rollback() { echo "rollback ai-clis: uninstall npm globals manually"; }
