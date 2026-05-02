#!/usr/bin/env bash
[[ -n "${__HI_MOD_BK:-}" ]] && return 0
__HI_MOD_BK=1

feature_id="backups"
feature_name="Backups (restic)"
feature_category="Backups"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="low"

detect() { command -v restic >/dev/null 2>&1; }
plan() { echo "Install restic; configure baseline backup units (no schedule by default in adopt mode)"; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role backups
    return 0
  fi
  pkg_install restic || return 1
}

rollback() { echo "rollback backups: remove timers/units manually"; }
