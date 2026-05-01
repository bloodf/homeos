#!/usr/bin/env bash
# Wizard for AI provider API keys. Writes to admin's secrets.env.
set -euo pipefail
ADMIN_USER="${SUDO_USER:-admin}"
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
SEC="$ADMIN_HOME/.config/homeos/secrets.env"

install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$(dirname "$SEC")"
[ -f "$SEC" ] || install -m 600 -o "$ADMIN_USER" -g "$ADMIN_USER" /dev/null "$SEC"

ask() {
	local key="$1" prompt="$2"
	local cur=""
	cur="$(grep -E "^${key}=" "$SEC" 2>/dev/null | head -1 | cut -d= -f2- || true)"
	local mask=""
	[ -n "$cur" ] && mask=" [currently set]"
	local v=""
	read -r -s -p "${prompt}${mask} (blank=skip): " v || true
	echo
	if [ -n "${v:-}" ]; then
		sed -i "/^${key}=/d" "$SEC"
		echo "${key}=${v}" >>"$SEC"
		echo "  set ${key}"
	fi
}

echo "== AI provider keys =="
ask ANTHROPIC_API_KEY "Anthropic (Claude)"
ask OPENAI_API_KEY "OpenAI (Codex/GPT)"
ask GOOGLE_API_KEY "Google (Gemini)"
ask CURSOR_API_KEY "Cursor Agent"
ask OPENROUTER_API_KEY "OpenRouter"
ask MOONSHOT_API_KEY "Moonshot (Kimi)"
ask GROQ_API_KEY "Groq"

chmod 600 "$SEC"
chown "$ADMIN_USER:$ADMIN_USER" "$SEC"
echo "secrets saved to $SEC"
