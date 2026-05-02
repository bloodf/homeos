#!/usr/bin/env bash
# Profile <-> feature map; module registry loader.

[[ -n "${__HI_PROFILES_SH:-}" ]] && return 0
__HI_PROFILES_SH=1

# Registry: arrays indexed by feature_id.
declare -gA HI_REG_NAME=()
declare -gA HI_REG_CATEGORY=()
declare -gA HI_REG_MODES=()
declare -gA HI_REG_DISTROS=()
declare -gA HI_REG_REQUIRES=()
declare -gA HI_REG_RISK=()
declare -gA HI_REG_FILE=()
declare -ga HI_REG_ORDER=()

# profiles::load_registry
# Source each module in subshell to read metadata, then store in arrays.
profiles::load_registry() {
  local mod
  for mod in "$HI_MODULES_DIR"/*.sh; do
    [[ -e "$mod" ]] || continue
    local meta
    meta="$(
      bash -c '
        set -e
        # shellcheck disable=SC1090
        . "$1"
        printf "ID=%s\n"        "${feature_id:-}"
        printf "NAME=%s\n"      "${feature_name:-}"
        printf "CATEGORY=%s\n"  "${feature_category:-}"
        printf "MODES=%s\n"     "${feature_modes:-}"
        printf "DISTROS=%s\n"   "${feature_distros:-}"
        printf "REQUIRES=%s\n"  "${feature_requires:-}"
        printf "RISK=%s\n"      "${feature_risk:-low}"
      ' _ "$mod" 2>/dev/null
    )" || continue
    local id="" name="" cat="" modes="" distros="" req="" risk=""
    while IFS='=' read -r k v; do
      case "$k" in
        ID) id="$v";;
        NAME) name="$v";;
        CATEGORY) cat="$v";;
        MODES) modes="$v";;
        DISTROS) distros="$v";;
        REQUIRES) req="$v";;
        RISK) risk="$v";;
      esac
    done <<< "$meta"
    [[ -z "$id" ]] && continue
    HI_REG_NAME[$id]="$name"
    HI_REG_CATEGORY[$id]="$cat"
    HI_REG_MODES[$id]="$modes"
    HI_REG_DISTROS[$id]="$distros"
    HI_REG_REQUIRES[$id]="$req"
    HI_REG_RISK[$id]="$risk"
    HI_REG_FILE[$id]="$mod"
    HI_REG_ORDER+=("$id")
  done
}

profiles::feature_ids() {
  local id
  for id in "${HI_REG_ORDER[@]}"; do
    echo "$id"
  done
}

# profiles::resolve <profile> -> echoes csv of feature ids
profiles::resolve() {
  local p="$1"
  case "$p" in
    minimal) echo "base";;
    server) echo "base,docker,cockpit,tailscale,caddy";;
    media) echo "base,docker,cockpit,tailscale,caddy,casaos,stacks";;
    ai) echo "base,docker,cockpit,tailscale,caddy,ai-clis";;
    full) echo "base,docker,cockpit,tailscale,caddy,casaos,stacks,ai-clis,monitoring,backups,security";;
    custom) echo "base";;
    *) echo "base";;
  esac
}

# profiles::merge <base-csv> <override-csv>
# Override syntax: id (add), -id (remove), +id (add explicit).
profiles::merge() {
  local base="$1" over="$2"
  declare -A m=()
  local f
  IFS=',' read -r -a __b <<< "$base"
  for f in "${__b[@]}"; do
    [[ -n "$f" ]] && m["$f"]=1
  done
  IFS=',' read -r -a __o <<< "$over"
  for f in "${__o[@]}"; do
    [[ -z "$f" ]] && continue
    case "$f" in
      -*) unset 'm[${f#-}]';;
      +*) m["${f#+}"]=1;;
      *) m["$f"]=1;;
    esac
  done
  # Preserve registry order.
  local out=""
  local id
  for id in "${HI_REG_ORDER[@]}"; do
    if [[ "${m[$id]:-0}" == "1" ]]; then
      out+="${out:+,}$id"
      unset 'm[$id]'
    fi
  done
  # Append any extras not in registry order at end.
  for id in "${!m[@]}"; do
    out+="${out:+,}$id"
  done
  echo "$out"
}

# profiles::categories - emit unique categories.
profiles::categories() {
  local id seen=""
  for id in "${HI_REG_ORDER[@]}"; do
    local c="${HI_REG_CATEGORY[$id]:-}"
    [[ -z "$c" ]] && continue
    case ",$seen," in
      *,"$c",*) ;;
      *) echo "$c"; seen+="${seen:+,}$c";;
    esac
  done
}
