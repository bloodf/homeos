#!/usr/bin/env bash
[[ -n "${__HI_MOD_CASAOS:-}" ]] && return 0
__HI_MOD_CASAOS=1

feature_id="casaos"
feature_name="CasaOS"
feature_category="Portals/UI"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="docker"
feature_risk="medium"

detect() { command -v casaos >/dev/null 2>&1 || [[ -d /etc/casaos ]]; }
plan() { echo "Install CasaOS via official script (requires docker)"; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role casaos
    return 0
  fi
  if [[ "${HI_DRY_RUN:-0}" == "1" ]]; then
    echo "[casaos] would install via official get.casaos.io script"
    return 0
  fi
  curl -fsSL https://get.casaos.io | bash
}

rollback() {
  echo "rollback casaos: run /usr/share/casaos/shell/uninstall.sh manually"
}
