#!/bin/bash
set -euo pipefail
echo "now: $(date -u +"%Y-%m-%dT%H:%M:%S.%3N")"

# set -x

########################################################################
# Required Inputs
########################################################################

if [[ -z ${RUFF_SELECT:-} ]]; then
    echo "ERROR: Env var 'RUFF_SELECT' must be defined (example: I,F401,FA,UP)"
    exit 1
fi
export RUFF_SELECT

if [[ -z ${DEFAULT_BRANCH:-} ]]; then
    echo "ERROR: Env var 'DEFAULT_BRANCH' must be defined"
    exit 1
fi

########################################################################
# Repo refs (all exported so downstream commands + python can use them)
########################################################################
git fetch origin --prune --no-tags
HEAD_SHA="$(git rev-parse HEAD)"
BASE_REF="origin/${DEFAULT_BRANCH}"
MERGE_BASE="$(git merge-base "$BASE_REF" "$HEAD_SHA")"

########################################################################
# Dump
########################################################################
echo "RUFF_SELECT=${RUFF_SELECT}"
echo "DEFAULT_BRANCH=${DEFAULT_BRANCH}"
echo "BASE_REF=${BASE_REF}"
echo "HEAD_SHA=${HEAD_SHA}"
echo "MERGE_BASE=${MERGE_BASE}"

########################################################################
# Temp files (export paths so python can read them)
########################################################################
CHANGED_FILES_FILE="$(mktemp)"
RUFF_OUT="$(mktemp)"

########################################################################
# Changed python files = diff from merge-base..HEAD (skip deletions)
########################################################################
git diff --name-only --diff-filter=ACMRT "${MERGE_BASE}..${HEAD_SHA}" -- '*.py' >"${CHANGED_FILES_FILE}"
if [[ ! -s ${CHANGED_FILES_FILE} ]]; then
    echo "No changed Python files."
    exit 0
else
    echo "Changed files:"
    cat "$CHANGED_FILES_FILE"
    echo
fi

########################################################################
# Ruff on changed files (no fixes), concise output for filtering
# - If no formatting violations are found -> exit 0
########################################################################
xargs -r ruff check --select "$RUFF_SELECT" --output-format concise \
    <"${CHANGED_FILES_FILE}" >"${RUFF_OUT}" &&
    echo "No ruff errors" || echo "Found ruff errors"
# ^^^ xargs feeds the file list into ruff as args

echo "Raw ruff output (will be paired down):"
cat "$RUFF_OUT"
echo

########################################################################
# Filter Ruff output using script
########################################################################
here_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export HEAD_SHA MERGE_BASE CHANGED_FILES_FILE RUFF_OUT
python3 "$here_dir"/filter_ruff.py
