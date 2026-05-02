#!/usr/bin/env bash
# HomeOS portable installer - main entrypoint.
# See docs/superpowers/specs/2026-05-02-portable-homeos-installer-design.md
set -euo pipefail
IFS=$'\n\t'

# Resolve script directory (handles symlinks).
HI_SELF="${BASH_SOURCE[0]}"
while [ -h "$HI_SELF" ]; do
  HI_DIR="$(cd -P "$(dirname "$HI_SELF")" && pwd)"
  HI_SELF="$(readlink "$HI_SELF")"
  [[ $HI_SELF != /* ]] && HI_SELF="$HI_DIR/$HI_SELF"
done
HI_DIR="$(cd -P "$(dirname "$HI_SELF")" && pwd)"
export HI_DIR
export HI_LIB_DIR="$HI_DIR/lib"
export HI_MODULES_DIR="$HI_DIR/modules"

# Default state.
HI_MODE=""
HI_PROFILE=""
HI_FEATURES=""
HI_YES="0"
HI_DRY_RUN="0"
HI_RECONFIGURE="0"
HI_CONFIRM_APPLIANCE="0"
HI_FORCE_UNSUPPORTED="0"
HI_SOURCE=""
HI_INTERACTIVE="1"

# shellcheck source=lib/ui.sh
. "$HI_LIB_DIR/ui.sh"
# shellcheck source=lib/distro.sh
. "$HI_LIB_DIR/distro.sh"
# shellcheck source=lib/pkg.sh
. "$HI_LIB_DIR/pkg.sh"
# shellcheck source=lib/profiles.sh
. "$HI_LIB_DIR/profiles.sh"
# shellcheck source=lib/runner.sh
. "$HI_LIB_DIR/runner.sh"
# shellcheck source=lib/ansible.sh
. "$HI_LIB_DIR/ansible.sh"

hi::usage() {
  cat <<EOF
HomeOS portable installer

Usage: $0 [flags]

Flags:
  --mode {adopt|appliance}        Operating mode.
  --profile {minimal|server|media|ai|full|custom}
                                  Profile to install.
  --features <csv>                Additional/override features (comma-separated).
  --yes                           Non-interactive: skip confirmations.
  --dry-run                       Print plan only, never mutate.
  --reconfigure                   Re-apply features even if already installed.
  --confirm-appliance             Required with --yes for appliance mode.
  --force-unsupported             Allow running on unsupported distros.
  --source <path>                 Path to HomeOS source tree (e.g. /opt/homeos).
  -h, --help                      Show this help.

With no flags: launch interactive menu.

Examples:
  sudo $0
  sudo $0 --mode adopt --profile media --features docker,caddy --yes
  sudo $0 --mode appliance --profile full --dry-run
  sudo $0 --mode appliance --profile full --yes --confirm-appliance
EOF
}

hi::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) HI_MODE="${2:-}"; shift 2;;
      --profile) HI_PROFILE="${2:-}"; shift 2;;
      --features) HI_FEATURES="${2:-}"; shift 2;;
      --yes) HI_YES="1"; HI_INTERACTIVE="0"; shift;;
      --dry-run) HI_DRY_RUN="1"; shift;;
      --reconfigure) HI_RECONFIGURE="1"; shift;;
      --confirm-appliance) HI_CONFIRM_APPLIANCE="1"; shift;;
      --force-unsupported) HI_FORCE_UNSUPPORTED="1"; shift;;
      --source) HI_SOURCE="${2:-}"; shift 2;;
      -h|--help) hi::usage; exit 0;;
      *) echo "Unknown flag: $1" >&2; hi::usage; exit 2;;
    esac
  done
}

hi::require_root_for_apply() {
  # Dry-run never mutates -> root not required.
  if [[ "$HI_DRY_RUN" == "1" ]]; then
    return 0
  fi
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: apply mode requires root. Re-run with sudo, or pass --dry-run." >&2
    exit 1
  fi
}

hi::validate_mode() {
  case "$HI_MODE" in
    adopt|appliance) ;;
    "") echo "ERROR: --mode is required (adopt|appliance)" >&2; exit 2;;
    *) echo "ERROR: invalid --mode: $HI_MODE" >&2; exit 2;;
  esac
}

hi::validate_profile() {
  case "$HI_PROFILE" in
    minimal|server|media|ai|full|custom) ;;
    "") echo "ERROR: --profile is required" >&2; exit 2;;
    *) echo "ERROR: invalid --profile: $HI_PROFILE" >&2; exit 2;;
  esac
}

hi::confirm_appliance() {
  # Appliance mode safeguard.
  if [[ "$HI_MODE" != "appliance" ]]; then
    return 0
  fi
  if [[ "$HI_DRY_RUN" == "1" ]]; then
    return 0
  fi
  if [[ "$HI_INTERACTIVE" == "0" ]]; then
    if [[ "$HI_YES" != "1" || "$HI_CONFIRM_APPLIANCE" != "1" ]]; then
      echo "ERROR: appliance mode in non-interactive runs requires both --yes and --confirm-appliance" >&2
      exit 2
    fi
    return 0
  fi
  ui::warn "Appliance mode performs system-wide takeover (hostname, users, SSH, firewall)."
  local typed
  typed="$(ui::prompt "Type HOMEOS to confirm appliance mode:")"
  if [[ "$typed" != "HOMEOS" ]]; then
    echo "Confirmation not given. Aborting." >&2
    exit 1
  fi
}

hi::interactive_flow() {
  ui::header "HomeOS portable installer"
  if [[ -z "$HI_MODE" ]]; then
    HI_MODE="$(ui::menu "Select mode:" adopt appliance)"
  fi
  if [[ -z "$HI_PROFILE" ]]; then
    HI_PROFILE="$(ui::menu "Select profile:" minimal server media ai full custom)"
  fi
  # Resolve features for selected profile.
  local features
  features="$(profiles::resolve "$HI_PROFILE")"
  if [[ -n "$HI_FEATURES" ]]; then
    features="$(profiles::merge "$features" "$HI_FEATURES")"
  fi
  # Allow user to add/remove individual features.
  if ui::confirm "Customize feature selection?"; then
    features="$(ui::multi_select_features "$features")"
  fi
  HI_FEATURES="$features"
}

hi::main() {
  hi::parse_args "$@"

  # If no flags supplied, force interactive.
  if [[ -z "$HI_MODE" && -z "$HI_PROFILE" && -z "$HI_FEATURES" && "$HI_YES" == "0" && "$HI_DRY_RUN" == "0" ]]; then
    HI_INTERACTIVE="1"
  fi

  # Distro detect & gate.
  distro::detect
  distro::require_supported "$HI_FORCE_UNSUPPORTED"

  # Load module registry.
  profiles::load_registry

  if [[ "$HI_INTERACTIVE" == "1" ]]; then
    hi::interactive_flow
  fi

  hi::validate_mode
  hi::validate_profile

  # Resolve final feature list.
  local final_features
  final_features="$(profiles::resolve "$HI_PROFILE")"
  if [[ -n "$HI_FEATURES" ]]; then
    final_features="$(profiles::merge "$final_features" "$HI_FEATURES")"
  fi

  # Filter by mode + distro.
  final_features="$(runner::filter_by_mode_distro "$final_features" "$HI_MODE" "${DISTRO_ID:-}")"
  # Resolve dependencies.
  final_features="$(runner::resolve_deps "$final_features")"

  # Print plan.
  runner::print_plan "$HI_MODE" "$HI_PROFILE" "$final_features"

  if [[ "$HI_DRY_RUN" == "1" ]]; then
    echo
    echo "Dry-run complete. No changes applied."
    return 0
  fi

  hi::require_root_for_apply
  hi::confirm_appliance

  if [[ "$HI_INTERACTIVE" == "1" && "$HI_YES" != "1" ]]; then
    if ! ui::confirm "Apply this plan?"; then
      echo "Aborted."
      exit 1
    fi
  elif [[ "$HI_YES" != "1" ]]; then
    echo "ERROR: non-interactive apply requires --yes" >&2
    exit 2
  fi

  runner::apply "$HI_MODE" "$HI_PROFILE" "$final_features"
}

hi::main "$@"
