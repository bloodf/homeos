#!/usr/bin/env bash
[[ -n "${__HI_MOD_CADDY:-}" ]] && return 0
__HI_MOD_CADDY=1

feature_id="caddy"
feature_name="Caddy reverse proxy"
feature_category="Network & access"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="medium"

detect() { command -v caddy >/dev/null 2>&1; }
plan() { echo "Install Caddy. In adopt mode, do not overwrite existing /etc/caddy config."; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role caddy
    return 0
  fi
  case "${DISTRO_FAMILY:-}" in
    debian)
      PKG_REPO_KEY="https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
      pkg_repo_add caddy-stable \
        "deb [signed-by=KEYRING] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main"
      pkg_install caddy
      ;;
    rhel)
      pkg_repo_add caddy "https://dl.cloudsmith.io/public/caddy/stable/config.rpm.txt"
      pkg_install caddy
      ;;
    *) ui::error "caddy: unsupported distro family"; return 1;;
  esac
  pkg_service_enable caddy
}

rollback() {
  [[ "${HI_DRY_RUN:-0}" == "1" ]] && return 0
  systemctl disable --now caddy 2>/dev/null || true
}
