#!/usr/bin/env bash
# Refresh GitHub tool commit pins in bootstrap/vars/main.yml from upstream HEAD.
set -euo pipefail

VARS_FILE="bootstrap/vars/main.yml"

repos=(
  "vectorize-io/hindsight"
  "tirth8205/code-review-graph"
  "vercel-labs/portless"
  "zilliztech/claude-context"
  "utooland/utoo"
  "NousResearch/hermes-agent"
  "volcengine/OpenViking"
  "opensoft/oh-my-opencode"
  "yeachan-heo/oh-my-claudecode"
  "thedotmack/claude-mem"
)

for repo in "${repos[@]}"; do
  sha="$(curl -fsSL "https://api.github.com/repos/${repo}/commits/HEAD" | awk -F'"' '/"sha":/ {print $4; exit}')"
  echo "${repo}: ${sha}"
done
echo
echo "Update SHAs in ${VARS_FILE} manually, or wire jq into this script for in-place edit."
