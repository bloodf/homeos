#!/usr/bin/env bash
# Dependency resolution, dry-run/apply, logging, state.

[[ -n "${__HI_RUNNER_SH:-}" ]] && return 0
__HI_RUNNER_SH=1

HI_LOG_FILE="/var/log/homeos-install.log"
HI_STATE_DIR="/var/lib/homeos/install-state"

runner::__ensure_state() {
  if [[ "${HI_DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi
  mkdir -p "$HI_STATE_DIR/installed-features" "$HI_STATE_DIR/logs" 2>/dev/null || true
  : >> "$HI_LOG_FILE" 2>/dev/null || true
}

runner::__log() {
  local msg="$*"
  # Redact common secret patterns.
  msg="$(printf '%s' "$msg" | sed -E 's/(token|secret|password|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1=REDACTED/Ig')"
  if [[ "${HI_DRY_RUN:-0}" != "1" ]]; then
    printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$msg" >> "$HI_LOG_FILE" 2>/dev/null || true
  fi
  printf '%s\n' "$msg"
}

# runner::filter_by_mode_distro <csv> <mode> <distro_id> -> csv
runner::filter_by_mode_distro() {
  local csv="$1" mode="$2" distro="$3"
  local out="" id
  IFS=',' read -r -a __ids <<< "$csv"
  for id in "${__ids[@]}"; do
    [[ -z "$id" ]] && continue
    local modes="${HI_REG_MODES[$id]:-adopt appliance}"
    local distros="${HI_REG_DISTROS[$id]:-debian ubuntu fedora rhel}"
    case " $modes " in *" $mode "*) ;; *) continue;; esac
    if [[ -n "$distro" ]]; then
      case " $distros " in *" $distro "*) ;; *)
        # Allow family fallback.
        local fam="${DISTRO_FAMILY:-}"
        case " $distros " in *" $fam "*) ;; *) continue;; esac
      ;;
      esac
    fi
    out+="${out:+,}$id"
  done
  echo "$out"
}

# runner::resolve_deps <csv> -> csv (topo-sorted, deps first).
runner::resolve_deps() {
  local csv="$1"
  declare -A want=()
  local id
  IFS=',' read -r -a __ids <<< "$csv"
  for id in "${__ids[@]}"; do
    [[ -n "$id" ]] && want["$id"]=1
  done
  # Expand requires transitively.
  local changed=1
  while (( changed )); do
    changed=0
    for id in "${!want[@]}"; do
      local req="${HI_REG_REQUIRES[$id]:-}"
      local r
      for r in $req; do
        if [[ -n "$r" && "${want[$r]:-0}" != "1" ]]; then
          want["$r"]=1
          changed=1
        fi
      done
    done
  done
  # Topo sort: emit ids whose deps already emitted.
  declare -A done_=()
  local out="" pass id req r ok
  for ((pass=0; pass<32; pass++)); do
    local progress=0
    for id in "${HI_REG_ORDER[@]}"; do
      [[ "${want[$id]:-0}" == "1" ]] || continue
      [[ "${done_[$id]:-0}" == "1" ]] && continue
      ok=1
      req="${HI_REG_REQUIRES[$id]:-}"
      for r in $req; do
        if [[ "${want[$r]:-0}" == "1" && "${done_[$r]:-0}" != "1" ]]; then
          ok=0; break
        fi
      done
      if (( ok )); then
        out+="${out:+,}$id"
        done_["$id"]=1
        progress=1
      fi
    done
    (( progress )) || break
  done
  # Append leftovers (cycles or unknown).
  for id in "${!want[@]}"; do
    [[ "${done_[$id]:-0}" == "1" ]] && continue
    out+="${out:+,}$id"
  done
  echo "$out"
}

# runner::print_plan <mode> <profile> <csv>
runner::print_plan() {
  local mode="$1" profile="$2" csv="$3"
  echo
  echo "Selected mode: $mode"
  echo "Selected profile: $profile"
  echo "Distro: ${DISTRO_ID:-unknown} ${DISTRO_VERSION:-} (family ${DISTRO_FAMILY:-?})"
  echo
  echo "Will change:"
  local id risk_high=""
  IFS=',' read -r -a __ids <<< "$csv"
  for id in "${__ids[@]}"; do
    [[ -z "$id" ]] && continue
    local nm="${HI_REG_NAME[$id]:-$id}"
    local rsk="${HI_REG_RISK[$id]:-low}"
    if [[ "$rsk" == "high" ]]; then
      risk_high+="${risk_high:+,}$id"
    else
      printf "  - %s (%s)\n" "$nm" "$id"
    fi
  done
  if [[ -n "$risk_high" ]]; then
    echo
    echo "High-risk changes:"
    IFS=',' read -r -a __h <<< "$risk_high"
    for id in "${__h[@]}"; do
      printf "  - %s (%s)\n" "${HI_REG_NAME[$id]:-$id}" "$id"
    done
  fi
  echo
}

# runner::feature_installed <id> -> 0 if state marker exists.
runner::feature_installed() {
  local id="$1"
  [[ -e "$HI_STATE_DIR/installed-features/$id" ]]
}

# runner::mark_installed <id>
runner::mark_installed() {
  local id="$1"
  [[ "${HI_DRY_RUN:-0}" == "1" ]] && return 0
  mkdir -p "$HI_STATE_DIR/installed-features" 2>/dev/null || true
  date -u +%FT%TZ > "$HI_STATE_DIR/installed-features/$id" 2>/dev/null || true
}

# runner::run_module <id> <fn> -> sources module in subshell, calls fn.
runner::run_module() {
  local id="$1" fn="$2"
  local file="${HI_REG_FILE[$id]:-}"
  [[ -z "$file" || ! -r "$file" ]] && { ui::error "module not found: $id"; return 1; }
  (
    set -euo pipefail
    # shellcheck disable=SC1090
    . "$HI_LIB_DIR/ui.sh"
    # shellcheck disable=SC1090
    . "$HI_LIB_DIR/pkg.sh"
    # shellcheck disable=SC1090
    . "$HI_LIB_DIR/ansible.sh"
    # shellcheck disable=SC1090
    . "$file"
    if declare -F "$fn" >/dev/null; then
      "$fn"
    else
      echo "module $id missing $fn" >&2
      exit 3
    fi
  )
}

# runner::apply <mode> <profile> <csv>
runner::apply() {
  local mode="$1" profile="$2" csv="$3"
  runner::__ensure_state
  if [[ "${HI_DRY_RUN:-0}" != "1" ]]; then
    echo "$profile" > "$HI_STATE_DIR/selected-profile" 2>/dev/null || true
  fi
  runner::__log "apply start mode=$mode profile=$profile features=$csv"
  local id
  IFS=',' read -r -a __ids <<< "$csv"
  for id in "${__ids[@]}"; do
    [[ -z "$id" ]] && continue
    if runner::feature_installed "$id" && [[ "${HI_RECONFIGURE:-0}" != "1" ]]; then
      ui::ok "skip $id (already installed; pass --reconfigure to re-run)"
      continue
    fi
    ui::info "applying $id ..."
    if runner::run_module "$id" apply; then
      runner::mark_installed "$id"
      runner::__log "feature $id applied"
      ui::ok "$id done"
    else
      runner::__log "feature $id FAILED"
      ui::error "$id failed; stopping"
      exit 1
    fi
  done
  runner::__log "apply complete"
  echo
  ui::ok "Install complete."
  echo "Logs: $HI_LOG_FILE"
  echo "State: $HI_STATE_DIR"
}
