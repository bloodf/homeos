#!/usr/bin/env bash
# Optional bridge to existing bootstrap/install.yml ansible roles.

[[ -n "${__HI_ANSIBLE_SH:-}" ]] && return 0
__HI_ANSIBLE_SH=1

ansible::available() {
  command -v ansible-playbook >/dev/null 2>&1
}

# ansible::source_dir - resolve bootstrap/ path.
ansible::source_dir() {
  local src="${HI_SOURCE:-}"
  if [[ -n "$src" && -d "$src/bootstrap" ]]; then
    echo "$src/bootstrap"
    return 0
  fi
  # Default: relative to install/ directory.
  local guess="${HI_DIR%/install}/bootstrap"
  if [[ -d "$guess" ]]; then
    echo "$guess"
    return 0
  fi
  if [[ -d "/opt/homeos/bootstrap" ]]; then
    echo "/opt/homeos/bootstrap"
    return 0
  fi
  echo ""
  return 1
}

# ansible::install - best-effort install of ansible.
ansible::install() {
  if ansible::available; then return 0; fi
  case "${DISTRO_FAMILY:-}" in
    debian) pkg_install ansible || return 1;;
    rhel) pkg_install ansible || pkg_install ansible-core || return 1;;
    *) return 1;;
  esac
}

# ansible::run_role <role-name> [extra_vars...]
# Runs a single-role mini playbook against localhost.
ansible::run_role() {
  local role="$1"; shift || true
  if [[ "${HI_DRY_RUN:-0}" == "1" ]]; then
    echo "[ansible] would run role: $role"
    return 0
  fi
  if ! ansible::available; then
    if ! ansible::install; then
      ui::error "ansible required for role '$role' but not installable"
      return 1
    fi
  fi
  local bdir; bdir="$(ansible::source_dir)" || true
  if [[ -z "$bdir" ]]; then
    ui::error "could not locate bootstrap/ source dir; pass --source <path>"
    return 1
  fi
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  cat > "$tmp/play.yml" <<EOF
- hosts: localhost
  connection: local
  become: true
  gather_facts: true
  vars_files:
    - $bdir/vars/main.yml
  roles:
    - role: $role
EOF
  ANSIBLE_ROLES_PATH="$bdir/roles" \
    ansible-playbook -i "localhost," -c local "$tmp/play.yml" "$@"
}
