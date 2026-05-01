#!/usr/bin/env bash
# Refresh GitHub tool commit pins in bootstrap/vars/main.yml from upstream HEAD.
# Usage:
#   refresh-pins.sh             # print SHAs only
#   refresh-pins.sh --write     # rewrite ref: in bootstrap/vars/main.yml in-place
set -eu
# pipefail intentionally OFF — `awk ... ; exit` SIGPIPEs upstream printf/curl.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VARS_FILE="${ROOT}/bootstrap/vars/main.yml"
WRITE=0
[ "${1:-}" = "--write" ] && WRITE=1

# tool name -> repo (must match `name:` keys in github_tools)
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

declare -A SHAS=()
for entry in "${tools[@]}"; do
  name="${entry%%|*}"; repo="${entry##*|}"
  body="$(curl -fsSL "${GH_AUTH[@]}" "https://api.github.com/repos/${repo}/commits/HEAD" || true)"
  sha="$(printf '%s' "$body" | awk -F'"' '/"sha":/ {print $4; exit}')"
  if [ -z "$sha" ]; then
    echo "WARN: no SHA for ${repo}, leaving existing ref" >&2
    continue
  fi
  SHAS["$name"]="$sha"
  printf '%-22s %s  %s\n' "$name" "$sha" "$repo"
done

if [ "$WRITE" -eq 0 ]; then
  echo
  echo "Run with --write to update ${VARS_FILE} in place."
  exit 0
fi

# In-place rewrite using python (yaml-safe).
python3 - "$VARS_FILE" <<PY
import re, sys, pathlib
shas = {
$(for name in "${!SHAS[@]}"; do printf '    %s: %s,\n' "\"$name\"" "\"${SHAS[$name]}\""; done)
}
p = pathlib.Path(sys.argv[1])
text = p.read_text()
# Match each tool entry line and replace ref: "<...>" preserving the "name" alignment.
def patch(m):
    name = m.group("name")
    ref  = shas.get(name)
    if not ref:
        return m.group(0)
    return re.sub(r'ref:\s*"[^"]*"', f'ref: "{ref}"', m.group(0))

pat = re.compile(
    r'-\s*\{\s*name:\s*"(?P<name>[^"]+)"[^\n]*\}',
    re.MULTILINE,
)
new = pat.sub(patch, text)
if new != text:
    p.write_text(new)
    print(f"updated {p}")
else:
    print("no changes")
PY
