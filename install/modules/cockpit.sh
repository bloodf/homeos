#!/usr/bin/env bash
[[ -n "${__HI_MOD_CKP:-}" ]] && return 0
__HI_MOD_CKP=1

feature_id="cockpit"
feature_name="Cockpit web admin"
feature_category="Portals/UI"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="low"

detect() { systemctl list-unit-files 2>/dev/null | grep -q '^cockpit\.socket'; }
plan() { echo "Install Cockpit; enable cockpit.socket on :9090"; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role cockpit
    return 0
  fi
  pkg_install cockpit || return 1
  pkg_service_enable cockpit.socket || true
}

rollback() {
  [[ "${HI_DRY_RUN:-0}" == "1" ]] && return 0
  systemctl disable --now cockpit.socket 2>/dev/null || true
}
