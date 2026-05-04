#!/usr/bin/env bash
set -euo pipefail

INSTALLER_PATH="${INSTALLER_PATH:-/install.sh}"

cat >/tmp/inject.conf <<'EOF'
INSTALL_BASE="no"
INSTALL_DOCKER="no"
INSTALL_NODE="no"
INSTALL_TAILSCALE="no"
INSTALL_CADDY="no"
INSTALL_LOCAL_DOMAINS="no"
INSTALL_COOLIFY="no"
INSTALL_CASAOS="no"
INSTALL_COCKPIT="no"
INSTALL_HOMEASSISTANT="no"
INSTALL_JELLYFIN="no"
INSTALL_VAULTWARDEN="no"
INSTALL_FIREWALL="no"
INSTALL_SSH_HARDEN="no"
INSTALL_AI_CLIS="no"
INSTALL_PI="no"
INSTALL_AI_PROJECTS="no"
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
INSTALL_LOCAL_DOMAINS="no"
INSTALL_COOLIFY="no"
INSTALL_CASAOS="no"
INSTALL_COCKPIT="no"
INSTALL_HOMEASSISTANT="no"
INSTALL_JELLYFIN="no"
INSTALL_VAULTWARDEN="no"
INSTALL_FIREWALL="no"
INSTALL_SSH_HARDEN="no"
INSTALL_AI_CLIS="no"
INSTALL_PI="no"
INSTALL_AI_PROJECTS="no"
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
grep -q 'node-exporter:9100' /opt/homeos/stacks/monitoring/prometheus.yml
grep -q 'HomeOS Server Overview' /opt/homeos/stacks/monitoring/dashboards/homeos-server.json
echo GRAFANA_PASSWORD_OK
echo GRAFANA_BIND_OK
echo GRAFANA_DASHBOARD_OK

cat >/tmp/domain.conf <<'EOF'
HOMEOS_MODE="full"
HOMEOS_UNATTENDED="yes"
INSTALL_BASE="no"
INSTALL_DOCKER="no"
INSTALL_NODE="no"
INSTALL_TAILSCALE="no"
INSTALL_CADDY="no"
INSTALL_LOCAL_DOMAINS="yes"
INSTALL_COOLIFY="no"
INSTALL_CASAOS="no"
INSTALL_COCKPIT="no"
INSTALL_HOMEASSISTANT="no"
INSTALL_JELLYFIN="no"
INSTALL_VAULTWARDEN="no"
INSTALL_FIREWALL="no"
INSTALL_SSH_HARDEN="no"
INSTALL_AI_CLIS="no"
INSTALL_PI="no"
INSTALL_AI_PROJECTS="no"
INSTALL_GITHUB_TOOLS="no"
INSTALL_MONITORING="no"
INSTALL_BACKUPS="no"
LOCAL_DOMAIN_ROOT="homeos.test"
LOCAL_DOMAIN_SERVER_IP="10.10.10.10"
EOF

bash "$INSTALLER_PATH" --config /tmp/domain.conf --unattended --skip-checks >/tmp/domain.out 2>&1
grep -q 'address=/.homeos.test/10.10.10.10' /etc/dnsmasq.d/homeos-local-domains.conf
echo LOCAL_DOMAINS_OK

cat >/tmp/ai-projects.conf <<'EOF'
HOMEOS_MODE="full"
HOMEOS_UNATTENDED="yes"
HOMEOS_DATA_DIR="/tmp/homeos-ai-test"
HOMEOS_ADMIN_HOME="/tmp/homeos-admin"
INSTALL_BASE="no"
INSTALL_DOCKER="no"
INSTALL_NODE="no"
INSTALL_TAILSCALE="no"
INSTALL_CADDY="no"
INSTALL_LOCAL_DOMAINS="no"
INSTALL_COOLIFY="no"
INSTALL_CASAOS="no"
INSTALL_COCKPIT="no"
INSTALL_HOMEASSISTANT="no"
INSTALL_JELLYFIN="no"
INSTALL_VAULTWARDEN="no"
INSTALL_FIREWALL="no"
INSTALL_SSH_HARDEN="no"
INSTALL_AI_CLIS="no"
INSTALL_PI="no"
INSTALL_AI_PROJECTS="yes"
INSTALL_GITHUB_TOOLS="no"
INSTALL_MONITORING="no"
INSTALL_BACKUPS="no"
AI_PROJECTS="oh-my-claudecode A11Y.md oh-my-openagent"
AI_PROJECT_TOOLS="claude,opencode,openagent"
AI_PROJECT_TARGETS="oh-my-claudecode:claude A11Y.md:shared,claude,opencode oh-my-openagent:openagent"
AI_PROJECT_INSTALL_MODE="manifest-only"
EOF

bash "$INSTALLER_PATH" --config /tmp/ai-projects.conf --unattended --skip-checks >/tmp/ai-projects.out 2>&1
grep -q $'oh-my-claudecode\thttps://github.com/yeachan-heo/oh-my-claudecode.git\tclaude' /tmp/homeos-ai-test/ai/manifest.tsv
grep -q $'A11Y.md\thttps://github.com/fecarrico/A11Y.md.git\tshared,claude,opencode' /tmp/homeos-ai-test/ai/manifest.tsv
test -L /tmp/homeos-admin/.claude/homeos/projects/oh-my-claudecode
test -L /tmp/homeos-admin/.config/opencode/homeos/projects/A11Y.md
test -L /tmp/homeos-admin/.config/openagent/homeos/projects/oh-my-openagent
test -d /tmp/homeos-admin/.claude/homeos/mcp/oh-my-claudecode
test -d /tmp/homeos-admin/.config/opencode/homeos/plugins/A11Y.md
! test -e /tmp/homeos-admin/.config/opencode/homeos/projects/oh-my-claudecode
grep -q 'does not edit global MCP server configuration files' /tmp/homeos-ai-test/ai/README.md
echo AI_PROJECTS_OK
