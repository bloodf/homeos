#!/usr/bin/env bash
# Distro detection.

[[ -n "${__HI_DISTRO_SH:-}" ]] && return 0
__HI_DISTRO_SH=1

DISTRO_ID=""
DISTRO_LIKE=""
DISTRO_VERSION=""
DISTRO_FAMILY=""

distro::detect() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-}"
    DISTRO_LIKE="${ID_LIKE:-}"
    DISTRO_VERSION="${VERSION_ID:-}"
  else
    DISTRO_ID=""
    DISTRO_LIKE=""
    DISTRO_VERSION=""
  fi
  case "$DISTRO_ID" in
    debian|ubuntu) DISTRO_FAMILY="debian";;
    fedora) DISTRO_FAMILY="rhel";;
    rhel|centos|rocky|almalinux) DISTRO_FAMILY="rhel";;
    *)
      case " $DISTRO_LIKE " in
        *" debian "*|*" ubuntu "*) DISTRO_FAMILY="debian";;
        *" rhel "*|*" fedora "*|*" centos "*) DISTRO_FAMILY="rhel";;
        *) DISTRO_FAMILY="";;
      esac
      ;;
  esac
  export DISTRO_ID DISTRO_LIKE DISTRO_VERSION DISTRO_FAMILY
}

# distro::is_supported -> 0 supported, 1 not.
distro::is_supported() {
  case "$DISTRO_ID" in
    debian|ubuntu|fedora|rhel|centos|rocky|almalinux) return 0;;
  esac
  case "$DISTRO_FAMILY" in
    debian|rhel) return 0;;
  esac
  return 1
}

# distro::require_supported <force-flag 0|1>
distro::require_supported() {
  local force="${1:-0}"
  if distro::is_supported; then
    return 0
  fi
  if [[ "$force" == "1" ]]; then
    ui::warn "Unsupported distro: ${DISTRO_ID:-unknown} (forced)"
    return 0
  fi
  ui::error "Unsupported distro: ${DISTRO_ID:-unknown}. Pass --force-unsupported to override."
  exit 1
}
