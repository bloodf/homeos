#!/usr/bin/env bash
set -euo pipefail

INSTALLER_PATH="${INSTALLER_PATH:-/install.sh}"

cat >/tmp/inject.conf <<'EOF'
INSTALL_BASE="no"
INSTALL_DOCKER="no"
INSTALL_NODE="no"
INSTALL_TAILSCALE="no"
INSTALL_CADDY="no"
INSTALL_CASAOS="no"
INSTALL_COCKPIT="no"
INSTALL_HOMEASSISTANT="no"
INSTALL_JELLYFIN="no"
INSTALL_VAULTWARDEN="no"
INSTALL_FIREWALL="no"
INSTALL_SSH_HARDEN="no"
INSTALL_AI_CLIS="no"
INSTALL_GITHUB_TOOLS="no"
INSTALL_MONITORING="no"
INSTALL_BACKUPS="no"
ANTHROPIC_API_KEY="$(echo PWNED >/tmp/pwned)"
EOF

bash "$INSTALLER_PATH" --config /tmp/inject.conf --dry-run --yes >/tmp/dryrun.out
test ! -e /tmp/pwned
echo CONFIG_INJECTION_OK

bash "$INSTALLER_PATH" --yes uninstall >/tmp/uninstall.out
! grep -q "Starting installation" /tmp/uninstall.out
echo UNINSTALL_PARSE_OK

bash "$INSTALLER_PATH" uninstall --yes >/tmp/uninstall2.out
! grep -q "Starting installation" /tmp/uninstall2.out
echo UNINSTALL_FIRST_ARG_OK

cat >/tmp/monitor.conf <<'EOF'
HOMEOS_MODE="full"
HOMEOS_UNATTENDED="yes"
INSTALL_BASE="no"
INSTALL_DOCKER="no"
INSTALL_NODE="no"
INSTALL_TAILSCALE="no"
INSTALL_CADDY="no"
INSTALL_CASAOS="no"
INSTALL_COCKPIT="no"
INSTALL_HOMEASSISTANT="no"
INSTALL_JELLYFIN="no"
INSTALL_VAULTWARDEN="no"
INSTALL_FIREWALL="no"
INSTALL_SSH_HARDEN="no"
INSTALL_AI_CLIS="no"
INSTALL_GITHUB_TOOLS="no"
INSTALL_MONITORING="yes"
INSTALL_BACKUPS="no"
GRAFANA_BIND_ADDRESS="100.64.0.10"
EOF

bash "$INSTALLER_PATH" --config /tmp/monitor.conf --unattended --skip-checks >/tmp/monitor.out 2>&1
secret="$(cat /var/lib/homeos/grafana-password.txt)"
test -n "$secret"
test "$secret" != "admin"
grep -q "GF_SECURITY_ADMIN_PASSWORD=$secret" /opt/homeos/stacks/monitoring/docker-compose.yml
grep -q '100.64.0.10:3000:3000' /opt/homeos/stacks/monitoring/docker-compose.yml
echo GRAFANA_PASSWORD_OK
echo GRAFANA_BIND_OK
