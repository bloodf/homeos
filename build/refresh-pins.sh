#!/usr/bin/env bash
# Refresh GitHub tool commit pins in bootstrap/vars/main.yml from upstream HEAD.
# Usage:
#   refresh-pins.sh             # print SHAs only
#   refresh-pins.sh --write     # rewrite refs in bootstrap/vars/main.yml in-place
#   refresh-pins.sh --check     # fail if committed refs differ from upstream HEAD
set -eu
# pipefail intentionally OFF — `awk ... ; exit` SIGPIPEs upstream printf/curl.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VARS_FILE="${ROOT}/bootstrap/vars/main.yml"
WRITE=0
CHECK=0
case "${1:-}" in
--write) WRITE=1 ;;
--check) CHECK=1 ;;
"") ;;
*)
	echo "usage: refresh-pins.sh [--write|--check]" >&2
	exit 2
	;;
esac

# tool name -> repo. Names must match either github_tools[].name or the
# dedicated hermes_agent_ref field in bootstrap/vars/main.yml.
declare -a tools=(
	"hindsight|vectorize-io/hindsight"
	"code-review-graph|tirth8205/code-review-graph"
	"portless|vercel-labs/portless"
	"claude-context|zilliztech/claude-context"
	"utoo|utooland/utoo"
	"hermes-agent|NousResearch/hermes-agent"
	"OpenViking|volcengine/OpenViking"
	"oh-my-opencode|opensoft/oh-my-opencode"
	"oh-my-claudecode|yeachan-heo/oh-my-claudecode"
	"claude-mem|thedotmack/claude-mem"
)

GH_AUTH=()
[ -n "${GITHUB_TOKEN:-}" ] && GH_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

json_entries=()
missing=()
for entry in "${tools[@]}"; do
	name="${entry%%|*}"
	repo="${entry##*|}"
	body="$(curl --retry 3 --connect-timeout 10 --max-time 30 -fsSL "${GH_AUTH[@]}" "https://api.github.com/repos/${repo}/commits/HEAD" || true)"
	sha="$(printf '%s' "$body" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sha", ""))' 2>/dev/null || true)"
	case "$sha" in
	[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
	*)
		echo "WARN: no valid HEAD SHA for ${repo}" >&2
		missing+=("$name")
		continue
		;;
	esac
	json_entries+=("$(python3 -c 'import json,sys; print(json.dumps([sys.argv[1], sys.argv[2]]))' "$name" "$sha")")
	printf '%-22s %s  %s\n' "$name" "$sha" "$repo"
done

if [ "$WRITE" -eq 0 ] && [ "$CHECK" -eq 0 ]; then
	echo
	echo "Run with --write to update ${VARS_FILE} in place, or --check to verify committed pins."
	exit 0
fi

if [ "${#missing[@]}" -ne 0 ]; then
	printf 'ERROR: refusing to continue with partial GitHub pins; missing: %s\n' "${missing[*]}" >&2
	exit 1
fi

PIN_JSON="[$(
	IFS=,
	echo "${json_entries[*]}"
)]" CHECK="$CHECK" WRITE="$WRITE" \
	python3 - "$VARS_FILE" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

shas = dict(json.loads(os.environ["PIN_JSON"]))
path = Path(sys.argv[1])
text = path.read_text()
patched = set()

def patch_tool(match):
    name = match.group("name")
    ref = shas.get(name)
    if not ref:
        return match.group(0)
    patched.add(name)
    return re.sub(r'ref:\s*"[0-9a-f]{40}"', f'ref: "{ref}"', match.group(0))

new = re.sub(
    r'-\s*\{\s*name:\s*"(?P<name>[^"]+)"[^\n]*\}',
    patch_tool,
    text,
)

hermes = shas.get("hermes-agent")
if hermes:
    new, count = re.subn(
        r'hermes_agent_ref:\s*"[0-9a-f]{40}"',
        f'hermes_agent_ref: "{hermes}"',
        new,
    )
    if count:
        patched.add("hermes-agent")

missing = sorted(set(shas) - patched)
if missing:
    print(f"ERROR: did not find vars/main.yml entries for: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

if os.environ.get("CHECK") == "1":
    if new != text:
        print(f"ERROR: committed GitHub pins in {path} are stale; run make pin-tools and commit the result", file=sys.stderr)
        sys.exit(1)
    print("committed GitHub pins match upstream HEAD")
elif new != text:
    path.write_text(new)
    print(f"updated {path}")
else:
    print("no changes")
PY
