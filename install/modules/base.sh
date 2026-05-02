#!/usr/bin/env bash
# Base system: essential tools.
[[ -n "${__HI_MOD_BASE:-}" ]] && return 0
__HI_MOD_BASE=1

feature_id="base"
feature_name="Base system tools"
feature_category="Base system"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires=""
feature_risk="low"

detect() {
  command -v curl >/dev/null 2>&1 && command -v git >/dev/null 2>&1
}

plan() {
  echo "Install: curl, ca-certificates, git, jq, gnupg, sudo"
}

apply() {
  pkg_update || true
  if [[ "${DISTRO_FAMILY:-}" == "debian" ]]; then
    pkg_install curl ca-certificates git jq gnupg sudo lsb-release
  else
    pkg_install curl ca-certificates git jq gnupg sudo
  fi
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role base || true
  fi
}

rollback() {
  echo "rollback base: no-op (system tools left in place)"
}
