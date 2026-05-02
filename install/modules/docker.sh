#!/usr/bin/env bash
# Docker CE.
[[ -n "${__HI_MOD_DOCKER:-}" ]] && return 0
__HI_MOD_DOCKER=1

feature_id="docker"
feature_name="Docker CE"
feature_category="Containers & orchestration"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="medium"

detect() {
  command -v docker >/dev/null 2>&1
}

plan() {
  echo "Install: Docker CE + buildx + compose plugin; enable docker.service"
}

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role docker
    return 0
  fi
  case "${DISTRO_FAMILY:-}" in
    debian)
      PKG_REPO_KEY="https://download.docker.com/linux/${DISTRO_ID}/gpg" \
      pkg_repo_add docker \
        "deb [arch=$(dpkg --print-architecture 2>/dev/null || echo amd64) signed-by=KEYRING] https://download.docker.com/linux/${DISTRO_ID} $(. /etc/os-release; echo "${VERSION_CODENAME}") stable"
      pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    rhel)
      pkg_repo_add docker "https://download.docker.com/linux/${DISTRO_ID}/docker-ce.repo"
      pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    *)
      ui::error "docker: unsupported distro family"
      return 1
      ;;
  esac
  pkg_service_enable docker
}

rollback() {
  echo "rollback docker: stop service (manual purge recommended)"
  [[ "${HI_DRY_RUN:-0}" == "1" ]] && return 0
  systemctl disable --now docker 2>/dev/null || true
}
