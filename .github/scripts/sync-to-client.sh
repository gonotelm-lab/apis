#!/usr/bin/env bash
set -euo pipefail
# Env:
#   CLIENT_DIR       - checkout of client repo
#   ARTIFACT_DIR     - generated files root (contains apps/...)
#   DEST_PREFIX      - "." for go, "src" for node
#   BRANCH           - branch to push (ignored when TAG_ONLY=1 except as local base)
#   SOURCE_SHA       - apis commit sha
#   SOURCE_REF       - branch or tag name for message
#   SOURCE_PR        - optional apis PR number associated with SOURCE_SHA
#   SOURCE_REPO      - apis repo full name (default gonotelm-lab/apis)
#   GIT_AUTHOR_NAME  - bot name
#   GIT_AUTHOR_EMAIL - bot email
#   PUSH_TAG         - optional; if set, create this tag
#   TAG_ONLY         - if 1, only push the tag (do not update any branch)
#   SKIP_PUSH        - if 1, commit locally only
#   RUN_GO_MOD_TIDY  - if 1, run go mod tidy after copying generated code

CLIENT_DIR="${CLIENT_DIR:?}"
ARTIFACT_DIR="${ARTIFACT_DIR:?}"
DEST_PREFIX="${DEST_PREFIX:?}"
BRANCH="${BRANCH:?}"
SOURCE_SHA="${SOURCE_SHA:?}"
SOURCE_REF="${SOURCE_REF:?}"
SOURCE_PR="${SOURCE_PR:-}"
SOURCE_REPO="${SOURCE_REPO:-gonotelm-lab/apis}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-gonotelm-lab-bot}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-bot@users.noreply.github.com}"
PUSH_TAG="${PUSH_TAG:-}"
TAG_ONLY="${TAG_ONLY:-0}"
RUN_GO_MOD_TIDY="${RUN_GO_MOD_TIDY:-0}"

cd "${CLIENT_DIR}"
git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"

BASE_BRANCH="main"
if [[ "${TAG_ONLY}" == "1" ]]; then
  git fetch origin "${BASE_BRANCH}"
  git checkout -B "${BASE_BRANCH}" "origin/${BASE_BRANCH}"
else
  git checkout -B "${BRANCH}"
fi

DEST="${CLIENT_DIR}"
if [[ "${DEST_PREFIX}" != "." ]]; then
  DEST="${CLIENT_DIR}/${DEST_PREFIX}"
  mkdir -p "${DEST}"
fi

# Replace generated apps tree; keep scaffold files (.gitignore, go.mod, package.json, ...).
if [[ -d "${DEST}/apps" ]]; then
  rm -rf "${DEST}/apps"
fi
mkdir -p "${DEST}"
cp -a "${ARTIFACT_DIR}/apps" "${DEST}/"

if [[ "${RUN_GO_MOD_TIDY}" == "1" ]]; then
  if [[ ! -f go.mod ]]; then
    echo "ERROR: RUN_GO_MOD_TIDY=1 but go.mod missing" >&2
    exit 1
  fi
  go mod tidy
fi

# Always record the exact apis commit this client tree was generated from.
# This guarantees a commit (and message) even when generated code is unchanged.
{
  echo "repo=${SOURCE_REPO}"
  echo "sha=${SOURCE_SHA}"
  echo "ref=${SOURCE_REF}"
  if [[ -n "${SOURCE_PR}" ]]; then
    echo "pr=${SOURCE_PR}"
    echo "pr_url=https://github.com/${SOURCE_REPO}/pull/${SOURCE_PR}"
  fi
  echo "commit_url=https://github.com/${SOURCE_REPO}/commit/${SOURCE_SHA}"
} > APIS_SOURCE

if [[ -n "${SOURCE_PR}" ]]; then
  COMMIT_MSG="chore: sync from apis@${SOURCE_SHA} (${SOURCE_REF}, PR #${SOURCE_PR})"
else
  COMMIT_MSG="chore: sync from apis@${SOURCE_SHA} (${SOURCE_REF})"
fi

git add -A
if git diff --cached --quiet; then
  echo "no content changes (unexpected if APIS_SOURCE should update)"
else
  git commit -m "${COMMIT_MSG}"
fi

COMMIT="$(git rev-parse HEAD)"

if [[ "${SKIP_PUSH:-}" == "1" ]]; then
  echo "SKIP_PUSH=1: not pushing"
  exit 0
fi

if [[ "${TAG_ONLY}" == "1" ]]; then
  if [[ -z "${PUSH_TAG}" ]]; then
    echo "ERROR: TAG_ONLY=1 requires PUSH_TAG" >&2
    exit 1
  fi
  # Keep the sync commit reachable via the tag only; do not advance client main
  # when the tag's generated tree differs from main.
  git tag -f "${PUSH_TAG}" "${COMMIT}"
  git reset --hard "origin/${BASE_BRANCH}"
  git push origin "refs/tags/${PUSH_TAG}" --force
  echo "pushed tag ${PUSH_TAG} -> ${COMMIT} (branch ${BASE_BRANCH} unchanged on remote)"
  exit 0
fi

# Always push branch ref so same-name branches exist even when generated code is unchanged.
git push -u origin "HEAD:${BRANCH}"

if [[ -n "${PUSH_TAG}" ]]; then
  git tag -f "${PUSH_TAG}" "${COMMIT}"
  git push origin "refs/tags/${PUSH_TAG}" --force
fi
