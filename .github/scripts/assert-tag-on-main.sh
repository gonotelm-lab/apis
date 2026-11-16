#!/usr/bin/env bash
set -euo pipefail
# Usage: assert-tag-on-main.sh <tag>
TAG="${1:?tag required}"
git fetch origin main --depth=0 2>/dev/null || git fetch origin main
if git merge-base --is-ancestor "refs/tags/${TAG}" origin/main; then
  echo "OK: tag ${TAG} is reachable from origin/main"
  exit 0
fi
echo "ERROR: tag ${TAG} is not on origin/main ancestry; refusing to sync clients" >&2
exit 1
