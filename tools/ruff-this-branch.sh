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

if [[ -z ${DEFAULT_BRANCH:-} ]]; then
    echo "ERROR: Env var 'DEFAULT_BRANCH' must be defined"
    exit 1
fi

########################################################################
# Repo refs (all exported so downstream commands + python can use them)
########################################################################
git fetch origin --prune --no-tags
HEAD_SHA="$(git rev-parse HEAD)"
MERGE_BASE="$(git merge-base "origin/${DEFAULT_BRANCH}" "$HEAD_SHA")"

########################################################################
# Dump
########################################################################
echo "RUFF_SELECT=${RUFF_SELECT}"
echo "DEFAULT_BRANCH=${DEFAULT_BRANCH}"
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
########################################################################
mapfile -t changed_files <"${CHANGED_FILES_FILE}" # use array since xargs changes return value
ruff_rc=0
ruff check --select "$RUFF_SELECT" --output-format concise \
    "${changed_files[@]}" >"${RUFF_OUT}" || ruff_rc=$?

if [[ $ruff_rc -eq 0 ]]; then
    echo "No ruff errors."
    exit 0
elif [[ $ruff_rc -eq 1 ]]; then
    echo "Found ruff errors (will be filtered):"
    cat "$RUFF_OUT"
else
    echo "ERROR: Ruff failed abnormally with exit code ${ruff_rc}"
    cat "${RUFF_OUT}"
    exit "$ruff_rc"
fi

########################################################################
# Filter Ruff output using script
########################################################################
here_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export HEAD_SHA MERGE_BASE CHANGED_FILES_FILE RUFF_OUT
python3 "$here_dir"/ruff_line_filter.py
