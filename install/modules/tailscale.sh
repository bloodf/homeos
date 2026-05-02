#!/usr/bin/env bash
[[ -n "${__HI_MOD_TS:-}" ]] && return 0
__HI_MOD_TS=1

feature_id="tailscale"
feature_name="Tailscale"
feature_category="Network & access"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="low"

detect() { command -v tailscale >/dev/null 2>&1; }
plan() { echo "Install Tailscale; enable tailscaled. (login left to user)"; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role tailscale
    return 0
  fi
  if [[ "${HI_DRY_RUN:-0}" == "1" ]]; then
    echo "[tailscale] would install via official script"
    return 0
  fi
  curl -fsSL https://tailscale.com/install.sh | sh
  pkg_service_enable tailscaled || true
}

rollback() {
  [[ "${HI_DRY_RUN:-0}" == "1" ]] && return 0
  systemctl disable --now tailscaled 2>/dev/null || true
}
