#!/usr/bin/env bash
# Package manager abstraction (apt/dnf).

[[ -n "${__HI_PKG_SH:-}" ]] && return 0
__HI_PKG_SH=1

# Internal: are we executing for real?
__pkg_should_run() {
  [[ "${HI_DRY_RUN:-0}" != "1" ]]
}

__pkg_log() {
  echo "[pkg] $*"
}

pkg::manager() {
  case "${DISTRO_FAMILY:-}" in
    debian) echo "apt";;
    rhel) command -v dnf >/dev/null 2>&1 && echo "dnf" || echo "yum";;
    *) echo "";;
  esac
}

pkg_update() {
  local mgr; mgr="$(pkg::manager)"
  __pkg_log "update via $mgr"
  __pkg_should_run || return 0
  case "$mgr" in
    apt) DEBIAN_FRONTEND=noninteractive apt-get update -y;;
    dnf|yum) "$mgr" -y makecache;;
    *) ui::warn "no package manager detected"; return 1;;
  esac
}

# pkg_install pkg1 pkg2 ...
pkg_install() {
  local mgr; mgr="$(pkg::manager)"
  __pkg_log "install [$mgr] $*"
  __pkg_should_run || return 0
  case "$mgr" in
    apt) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@";;
    dnf|yum) "$mgr" -y install "$@";;
    *) return 1;;
  esac
}

# pkg_is_installed <name>
pkg_is_installed() {
  local p="$1"
  local mgr; mgr="$(pkg::manager)"
  case "$mgr" in
    apt) dpkg -s "$p" >/dev/null 2>&1;;
    dnf|yum) rpm -q "$p" >/dev/null 2>&1;;
    *) return 1;;
  esac
}

# pkg_repo_add <name> <repo-spec>
# Debian: <repo-spec> is a deb-line. Optionally precede with key url via PKG_REPO_KEY env.
# RHEL: <repo-spec> is a .repo file URL or content.
pkg_repo_add() {
  local name="$1" spec="$2"
  local mgr; mgr="$(pkg::manager)"
  __pkg_log "repo-add [$mgr] $name"
  __pkg_should_run || return 0
  case "$mgr" in
    apt)
      local list="/etc/apt/sources.list.d/${name}.list"
      if [[ -n "${PKG_REPO_KEY:-}" ]]; then
        if ! command -v gpg >/dev/null 2>&1; then
          pkg_install gnupg || { ui::error "gnupg required for repo key setup"; return 1; }
        fi
        local keyring="/usr/share/keyrings/${name}-archive-keyring.gpg"
        mkdir -p /usr/share/keyrings
        curl -fsSL "$PKG_REPO_KEY" | gpg --dearmor -o "$keyring"
        echo "$spec" | sed "s|signed-by=KEYRING|signed-by=$keyring|" > "$list"
      else
        echo "$spec" > "$list"
      fi
      DEBIAN_FRONTEND=noninteractive apt-get update -y
      ;;
    dnf|yum)
      if [[ "$spec" == http*://* ]]; then
        "$mgr" config-manager --add-repo "$spec" || \
          curl -fsSL "$spec" -o "/etc/yum.repos.d/${name}.repo"
      else
        printf '%s\n' "$spec" > "/etc/yum.repos.d/${name}.repo"
      fi
      ;;
    *) return 1;;
  esac
}

# pkg_service_enable <name>
pkg_service_enable() {
  local svc="$1"
  __pkg_log "service-enable $svc"
  __pkg_should_run || return 0
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now "$svc"
  else
    ui::warn "no systemctl; cannot enable $svc"
    return 1
  fi
}
