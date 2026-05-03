#!/usr/bin/env bash
# HomeOS portable installer bootstrap.
#
# One-liner usage (paste into SSH):
#
#   curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/install/bootstrap.sh | sudo bash
#
# With arguments forwarded to homeos-install.sh:
#
#   curl -fsSL https://raw.githubusercontent.com/bloodf/homeos/main/install/bootstrap.sh \
#     | sudo bash -s -- --mode adopt --profile server --yes
#
# Environment overrides:
#   HOMEOS_REPO   git remote (default: https://github.com/bloodf/homeos.git)
#   HOMEOS_REF    branch/tag/sha (default: main)
#   HOMEOS_DIR    install dir (default: /opt/homeos)

set -euo pipefail
IFS=$'\n\t'

HOMEOS_REPO="${HOMEOS_REPO:-https://github.com/bloodf/homeos.git}"
HOMEOS_REF="${HOMEOS_REF:-main}"
HOMEOS_DIR="${HOMEOS_DIR:-/opt/homeos}"

log()  { printf '\033[1;36m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "Run as root. Try: curl -fsSL <url> | sudo bash"
fi

ensure_pkg() {
  local pkg="$1"
  command -v "$pkg" >/dev/null 2>&1 && return 0
  log "Installing prerequisite: $pkg"
  if command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q "$pkg"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y -q "$pkg"
  else
    die "No supported package manager (apt/dnf/yum) for installing $pkg"
  fi
}

ensure_pkg git
ensure_pkg ca-certificates || true

if [[ -d "$HOMEOS_DIR/.git" ]]; then
  log "Updating existing checkout at $HOMEOS_DIR"
  git -C "$HOMEOS_DIR" fetch --quiet origin "$HOMEOS_REF"
  git -C "$HOMEOS_DIR" checkout --quiet "$HOMEOS_REF"
  git -C "$HOMEOS_DIR" reset --hard --quiet "origin/$HOMEOS_REF" 2>/dev/null \
    || git -C "$HOMEOS_DIR" reset --hard --quiet "$HOMEOS_REF"
else
  if [[ -e "$HOMEOS_DIR" ]]; then
    die "$HOMEOS_DIR exists but is not a git checkout. Move it aside or set HOMEOS_DIR."
  fi
  log "Cloning $HOMEOS_REPO ($HOMEOS_REF) into $HOMEOS_DIR"
  mkdir -p "$(dirname "$HOMEOS_DIR")"
  if ! git clone --quiet --depth 1 --branch "$HOMEOS_REF" "$HOMEOS_REPO" "$HOMEOS_DIR" 2>/dev/null; then
    log "Shallow clone failed; trying full clone..."
    if ! git clone --quiet "$HOMEOS_REPO" "$HOMEOS_DIR" 2>/dev/null; then
      die "Git clone failed. Check network connectivity and repo URL."
    fi
  fi
fi

INSTALLER="$HOMEOS_DIR/install/homeos-install.sh"
[[ -x "$INSTALLER" ]] || chmod +x "$INSTALLER" 2>/dev/null || true
[[ -f "$INSTALLER" ]] || die "Installer not found at $INSTALLER"

log "Launching installer"
exec "$INSTALLER" --source "$HOMEOS_DIR" "$@"
