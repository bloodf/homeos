#!/usr/bin/env bash
# Pure-bash UI: header, menu, multi-select, confirm, prompt.
# No dialog/whiptail/fzf/python.

[[ -n "${__HI_UI_SH:-}" ]] && return 0
__HI_UI_SH=1

# ANSI helpers (degrade gracefully if no tty).
if [[ -t 1 ]]; then
  __UI_BOLD=$'\033[1m'
  __UI_DIM=$'\033[2m'
  __UI_RED=$'\033[31m'
  __UI_GREEN=$'\033[32m'
  __UI_YELLOW=$'\033[33m'
  __UI_CYAN=$'\033[36m'
  __UI_RESET=$'\033[0m'
else
  __UI_BOLD=""; __UI_DIM=""; __UI_RED=""; __UI_GREEN=""; __UI_YELLOW=""; __UI_CYAN=""; __UI_RESET=""
fi

ui::header() {
  local title="$1"
  echo
  echo "${__UI_BOLD}${__UI_CYAN}=== ${title} ===${__UI_RESET}"
  echo
}

ui::info()  { echo "${__UI_CYAN}[i]${__UI_RESET} $*"; }
ui::warn()  { echo "${__UI_YELLOW}[!]${__UI_RESET} $*" >&2; }
ui::error() { echo "${__UI_RED}[x]${__UI_RESET} $*" >&2; }
ui::ok()    { echo "${__UI_GREEN}[+]${__UI_RESET} $*"; }

# ui::prompt "Question:" [default]
# Echoes user input.
ui::prompt() {
  local q="$1" def="${2:-}"
  local ans
  if [[ -n "$def" ]]; then
    read -r -p "$q [$def] " ans </dev/tty || true
    echo "${ans:-$def}"
  else
    read -r -p "$q " ans </dev/tty || true
    echo "$ans"
  fi
}

# ui::confirm "Question?" -> 0 yes, 1 no
ui::confirm() {
  local q="$1" ans
  read -r -p "$q [y/N] " ans </dev/tty || true
  case "${ans,,}" in
    y|yes) return 0;;
    *) return 1;;
  esac
}

# ui::menu "Title" opt1 opt2 ...
# Numbered selection. Echoes chosen option.
ui::menu() {
  local title="$1"; shift
  local opts=("$@")
  local i choice
  echo "${__UI_BOLD}${title}${__UI_RESET}" >&2
  for i in "${!opts[@]}"; do
    printf "  %d) %s\n" "$((i+1))" "${opts[$i]}" >&2
  done
  while true; do
    read -r -p "Choose [1-${#opts[@]}]: " choice </dev/tty || true
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#opts[@]} )); then
      echo "${opts[$((choice-1))]}"
      return 0
    fi
    echo "Invalid selection." >&2
  done
}

# ui::multi_select_features "csv-of-currently-selected"
# Reads registry from profiles::feature_ids. Lets user toggle by number.
# Echoes new csv.
ui::multi_select_features() {
  local current_csv="$1"
  local -a all
  # Pull all feature IDs from registry.
  if declare -F profiles::feature_ids >/dev/null; then
    mapfile -t all < <(profiles::feature_ids)
  else
    echo "$current_csv"
    return 0
  fi
  # Build selected map.
  declare -A sel=()
  local f
  IFS=',' read -r -a __cur <<< "$current_csv"
  for f in "${__cur[@]}"; do
    [[ -n "$f" ]] && sel["$f"]=1
  done
  while true; do
    echo
    echo "${__UI_BOLD}Feature selection:${__UI_RESET}" >&2
    local i id mark
    for i in "${!all[@]}"; do
      id="${all[$i]}"
      mark=" "
      [[ "${sel[$id]:-0}" == "1" ]] && mark="x"
      printf "  [%s] %2d) %s\n" "$mark" "$((i+1))" "$id" >&2
    done
    echo "Enter number to toggle, 'a' to add by id, 'r' to remove by id, 'd' done:" >&2
    local input
    read -r -p "> " input </dev/tty || true
    case "$input" in
      d|done|"") break;;
      a)
        local nid; nid="$(ui::prompt "Feature id to add:")"
        [[ -n "$nid" ]] && sel["$nid"]=1
        ;;
      r)
        local rid; rid="$(ui::prompt "Feature id to remove:")"
        [[ -n "$rid" ]] && unset 'sel[$rid]'
        ;;
      *)
        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#all[@]} )); then
          local fid="${all[$((input-1))]}"
          if [[ "${sel[$fid]:-0}" == "1" ]]; then
            unset 'sel[$fid]'
          else
            sel["$fid"]=1
          fi
        else
          echo "Invalid input." >&2
        fi
        ;;
    esac
  done
  # Emit csv preserving registry order.
  local out=""
  for f in "${all[@]}"; do
    if [[ "${sel[$f]:-0}" == "1" ]]; then
      out+="${out:+,}$f"
    fi
  done
  echo "$out"
}
