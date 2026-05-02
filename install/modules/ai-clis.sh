#!/usr/bin/env bash
[[ -n "${__HI_MOD_AI:-}" ]] && return 0
__HI_MOD_AI=1

feature_id="ai-clis"
feature_name="AI CLIs (claude, codex, gemini)"
feature_category="AI/dev tools"
feature_modes="adopt appliance"
feature_distros="debian ubuntu fedora rhel"
feature_requires="base"
feature_risk="low"

detect() {
  command -v claude >/dev/null 2>&1 || command -v codex >/dev/null 2>&1 || command -v gemini >/dev/null 2>&1
}

plan() { echo "Install AI CLIs via existing 'ai-clis' ansible role"; }

apply() {
  if ansible::available && ansible::source_dir >/dev/null; then
    ansible::run_role ai-clis
  else
    ui::warn "ai-clis: ansible role required; install ansible or pass --source"
    return 0
  fi
}

rollback() { echo "rollback ai-clis: uninstall npm globals manually"; }
