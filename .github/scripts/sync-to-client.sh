#!/usr/bin/env bash
set -euo pipefail
# Env:
#   CLIENT_DIR       - checkout of client repo
#   ARTIFACT_DIR     - generated files root (contains apps/...)
#   DEST_PREFIX      - "." for go, "src" for node
#   BRANCH           - branch to push
#   SOURCE_SHA       - apis commit sha
#   SOURCE_REF       - branch or tag name for message
#   GIT_AUTHOR_NAME  - bot name
#   GIT_AUTHOR_EMAIL - bot email
#   PUSH_TAG         - optional; if set, create this tag after push
#   SKIP_PUSH        - if 1, commit locally only

CLIENT_DIR="${CLIENT_DIR:?}"
ARTIFACT_DIR="${ARTIFACT_DIR:?}"
DEST_PREFIX="${DEST_PREFIX:?}"
BRANCH="${BRANCH:?}"
SOURCE_SHA="${SOURCE_SHA:?}"
SOURCE_REF="${SOURCE_REF:?}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-gonotelm-lab-bot}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-bot@users.noreply.github.com}"
PUSH_TAG="${PUSH_TAG:-}"

DEST="${CLIENT_DIR}"
if [[ "${DEST_PREFIX}" != "." ]]; then
  DEST="${CLIENT_DIR}/${DEST_PREFIX}"
  mkdir -p "${DEST}"
fi

# Remove previously generated apps tree under dest; keep scaffold files at repo root.
if [[ -d "${DEST}/apps" ]]; then
  rm -rf "${DEST}/apps"
fi

mkdir -p "${DEST}"
cp -a "${ARTIFACT_DIR}/apps" "${DEST}/"

cd "${CLIENT_DIR}"
git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"
git checkout -B "${BRANCH}"

git add -A
if git diff --cached --quiet; then
  echo "no changes for ${BRANCH}"
  if [[ "${SKIP_PUSH:-}" == "1" ]]; then
    echo "SKIP_PUSH=1: not pushing"
    exit 0
  fi
  if [[ -n "${PUSH_TAG}" ]]; then
    git tag -f "${PUSH_TAG}"
    git push origin "refs/tags/${PUSH_TAG}" --force
  fi
  exit 0
fi

git commit -m "chore: sync from apis@${SOURCE_SHA} (${SOURCE_REF})"

if [[ "${SKIP_PUSH:-}" == "1" ]]; then
  echo "SKIP_PUSH=1: not pushing"
  exit 0
fi

git push -u origin "HEAD:${BRANCH}"

if [[ -n "${PUSH_TAG}" ]]; then
  git tag -f "${PUSH_TAG}"
  git push origin "refs/tags/${PUSH_TAG}" --force
fi
