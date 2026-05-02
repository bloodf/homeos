#!/usr/bin/env bash
[[ -n "${__HI_MOD_STACKS:-}" ]] && return 0
__HI_MOD_STACKS=1

feature_id="stacks"
feature_name="HomeOS app stacks"
feature_category="Media"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="docker"
feature_risk="medium"

detect() { [[ -d /opt/homeos/stacks ]] || [[ -d /var/lib/homeos/stacks ]]; }
plan() { echo "Deploy compose stacks (jellyfin/arr/etc) via ansible 'stacks' role"; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role stacks
  else
    ui::warn "stacks role requires ansible + bootstrap source dir; skipping"
    return 0
  fi
}

rollback() {
  echo "rollback stacks: bring down compose stacks manually"
}
