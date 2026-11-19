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
#   RUN_NODE_BUILD   - if 1, install deps and run npm run build after copying generated code

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
RUN_NODE_BUILD="${RUN_NODE_BUILD:-0}"

cd "${CLIENT_DIR}"
git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"

BASE_BRANCH="main"
if [[ "${TAG_ONLY}" == "1" ]]; then
  git fetch origin "${BASE_BRANCH}"
  git checkout -B "${BASE_BRANCH}" "origin/${BASE_BRANCH}"
elif git fetch origin "refs/heads/${BRANCH}:refs/remotes/origin/${BRANCH}" 2>/dev/null; then
  # Continue an existing client branch instead of resetting it to main, so
  # branch-local scaffold (package.json, hand-written entries) survives until
  # it lands on main.
  git checkout -B "${BRANCH}" "origin/${BRANCH}"
else
  git checkout -B "${BRANCH}"
fi

DEST="${CLIENT_DIR}"
if [[ "${DEST_PREFIX}" != "." ]]; then
  DEST="${CLIENT_DIR}/${DEST_PREFIX}"
  mkdir -p "${DEST}"
fi

# Replace generated trees; keep scaffold files (.gitignore, go.mod, package.json, ...).
for dir in apps google buf; do
  rm -rf "${DEST}/${dir}"
  if [[ -d "${ARTIFACT_DIR}/${dir}" ]]; then
    cp -a "${ARTIFACT_DIR}/${dir}" "${DEST}/"
  fi
done

if [[ "${RUN_GO_MOD_TIDY}" == "1" ]]; then
  if [[ ! -f go.mod ]]; then
    echo "ERROR: RUN_GO_MOD_TIDY=1 but go.mod missing" >&2
    exit 1
  fi
  go mod tidy
fi

if [[ "${RUN_NODE_BUILD}" == "1" ]]; then
  if [[ -f package-lock.json ]]; then
    npm ci --no-audit --no-fund --ignore-scripts
  else
    npm install --no-audit --no-fund --ignore-scripts
  fi
  npm run build
  test -f dist/cjs/index.js
  test -f dist/esm/index.js
  test -f dist/cjs/index.d.ts
  test -f dist/esm/index.d.ts
  test -f dist/cjs/callback.js
  test -f dist/esm/callback.js
  test -f dist/cjs/callback.d.ts
  test -f dist/esm/callback.d.ts
  npm test
  if [[ -n "${PUSH_TAG}" ]]; then
    npm pkg set version="${PUSH_TAG#v}"
  fi
fi

SHORT_SHA="${SOURCE_SHA:0:7}"
COMMIT_URL="https://github.com/${SOURCE_REPO}/commit/${SHORT_SHA}"
PR_URL=""
if [[ -n "${SOURCE_PR}" ]]; then
  PR_URL="https://github.com/${SOURCE_REPO}/pull/${SOURCE_PR}"
fi

# Always record the exact apis commit this client tree was generated from.
# This guarantees a commit (and message) even when generated code is unchanged.
{
  echo "repo=${SOURCE_REPO}"
  echo "sha=${SOURCE_SHA}"
  echo "short_sha=${SHORT_SHA}"
  echo "ref=${SOURCE_REF}"
  echo "commit_url=${COMMIT_URL}"
  if [[ -n "${SOURCE_PR}" ]]; then
    echo "pr=${SOURCE_PR}"
    echo "pr_url=${PR_URL}"
  fi
} > APIS_SOURCE

# Full GitHub URLs so the commit message is clickable in the GitHub UI.
if [[ -n "${PR_URL}" ]]; then
  COMMIT_MSG="chore: sync from ${COMMIT_URL} (${SOURCE_REF}) ${PR_URL}"
else
  COMMIT_MSG="chore: sync from ${COMMIT_URL} (${SOURCE_REF})"
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

# Client feature branches are bot-owned mirrors rebuilt from main + generated code.
# Each sync rewrites the branch tip, so a plain push is non-fast-forward after the first sync.
git fetch origin "refs/heads/${BRANCH}:refs/remotes/origin/${BRANCH}" 2>/dev/null || true
git push -u --force-with-lease origin "HEAD:${BRANCH}"

if [[ -n "${PUSH_TAG}" ]]; then
  git tag -f "${PUSH_TAG}" "${COMMIT}"
  git push origin "refs/tags/${PUSH_TAG}" --force
fi
