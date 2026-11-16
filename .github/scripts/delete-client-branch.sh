#!/usr/bin/env bash
set -euo pipefail
# Env:
#   BRANCH          - branch to delete
#   CLIENT_REPO     - e.g. gonotelm-lab/apis-go-client
#   GH_TOKEN        - token with contents:write
BRANCH="${BRANCH:?}"
CLIENT_REPO="${CLIENT_REPO:?}"
GH_TOKEN="${GH_TOKEN:?}"

if [[ "${BRANCH}" == "main" ]]; then
  echo "skip: refusing to delete main on ${CLIENT_REPO}"
  exit 0
fi

export GH_TOKEN
if gh api "repos/${CLIENT_REPO}/branches/${BRANCH}" --silent 2>/dev/null; then
  gh api -X DELETE "repos/${CLIENT_REPO}/git/refs/heads/${BRANCH}"
  echo "deleted ${CLIENT_REPO}@${BRANCH}"
else
  echo "skip: ${CLIENT_REPO}@${BRANCH} does not exist"
fi
