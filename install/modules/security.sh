#!/usr/bin/env bash
[[ -n "${__HI_MOD_SEC:-}" ]] && return 0
__HI_MOD_SEC=1

feature_id="security"
feature_name="Security hardening (SSH + firewall + audit)"
feature_category="Security/audit"
feature_modes="appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="high"

detect() { [[ -f /etc/ssh/sshd_config.d/99-homeos.conf ]]; }

plan() {
  cat <<EOF
Will harden the system:
  - SSH: disable password auth, disable root login
  - Firewall: enable default deny + allow ssh/cockpit/caddy
  - Audit: enable auditd
This is HIGH RISK and only runs in appliance mode.
EOF
}

apply() {
  if [[ "${HI_MODE:-}" != "appliance" ]]; then
    ui::warn "security module is appliance-only; skipping"
    return 0
  fi
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role ssh || true
    return 0
  fi
  if [[ "${HI_DRY_RUN:-0}" == "1" ]]; then
    echo "[security] would harden SSH + firewall"
    return 0
  fi
  install -d -m 0755 /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/99-homeos.conf <<EOF
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
EOF
  systemctl reload sshd 2>/dev/null || systemctl restart sshd 2>/dev/null || true
  case "${DISTRO_FAMILY:-}" in
    debian)
      pkg_install ufw || true
      ufw --force default deny incoming || true
      ufw --force default allow outgoing || true
      ufw --force allow OpenSSH || true
      ufw --force allow 9090/tcp || true
      ufw --force allow 80/tcp || true
      ufw --force allow 443/tcp || true
      ufw --force enable || true
      ;;
    rhel)
      pkg_install firewalld || true
      systemctl enable --now firewalld || true
      firewall-cmd --permanent --add-service=ssh || true
      firewall-cmd --permanent --add-service=cockpit || true
      firewall-cmd --permanent --add-service=http || true
      firewall-cmd --permanent --add-service=https || true
      firewall-cmd --reload || true
      ;;
  esac
  pkg_install auditd 2>/dev/null || pkg_install audit || true
  pkg_service_enable auditd 2>/dev/null || true
}

rollback() {
  [[ "${HI_DRY_RUN:-0}" == "1" ]] && return 0
  rm -f /etc/ssh/sshd_config.d/99-homeos.conf 2>/dev/null || true
  systemctl reload sshd 2>/dev/null || true
}
