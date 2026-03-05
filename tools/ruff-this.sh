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

export HEAD_SHA
HEAD_SHA="$(git rev-parse HEAD)"

export BASE_REF
BASE_REF="origin/${DEFAULT_BRANCH}"

export MERGE_BASE
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
# Temp files (export paths so python can read/write them)
########################################################################
export PR_SHAS_FILE
PR_SHAS_FILE="$(mktemp)"

export CHANGED_FILES_FILE
CHANGED_FILES_FILE="$(mktemp)"

export RUFF_OUT
RUFF_OUT="$(mktemp)"

export CHANGED_LINES_FILE
CHANGED_LINES_FILE="$(mktemp)"

########################################################################
# Branch's commit SHAs = merge-base..HEAD
########################################################################
git rev-list "${MERGE_BASE}..${HEAD_SHA}" >"${PR_SHAS_FILE}"

echo "SHAs for this Branch:"
cat "$PR_SHAS_FILE"
echo

########################################################################
# Changed python files = diff from merge-base..HEAD (skip deletions)
########################################################################
git diff --name-only --diff-filter=ACMRT "${MERGE_BASE}..${HEAD_SHA}" -- '*.py' >"${CHANGED_FILES_FILE}"
if [[ ! -s ${CHANGED_FILES_FILE} ]]; then
    echo "No changed Python files."
    exit 0
fi

echo "Changed files:"
cat "$CHANGED_FILES_FILE"
echo

########################################################################
# Ruff on changed files (no fixes), concise output for filtering
# - If no formatting violations are found -> exit 0
########################################################################
xargs -r ruff check --select I,F401,FA,UP --output-format concise \
    <"${CHANGED_FILES_FILE}" >"${RUFF_OUT}" &&
    echo "No ruff errors" || echo "Found ruff errors"
# ^^^ xargs feeds the file list into ruff as args

echo "Raw ruff output (will be paired down):"
cat "$RUFF_OUT"
echo

########################################################################
# Build allowlist: "fpath:lineno" for lines last-touched by Branch's SHAs (blame HEAD)
########################################################################
python3 -c '
import os
import re
import subprocess

PR_SHAS = set(open(os.environ["PR_SHAS_FILE"], "r").read().split())

CHANGED_FILES = [
    x.strip()
    for x in open(os.environ["CHANGED_FILES_FILE"], "r")
    if x.strip()
]

HEADER_RE = re.compile(
    r"^(?P<sha>\^?[0-9a-f]{40})\s+\d+\s+(?P<final_lineno>\d+)\b"
)

changed_lines = set()

for path in CHANGED_FILES:
    txt = subprocess.check_output(
        ["git", "blame", "--line-porcelain", os.environ["HEAD_SHA"], "--", path],
        text=True,
    )
    for line in txt.splitlines():
        m = HEADER_RE.match(line)
        if not m:
            continue
        sha = m.group("sha").lstrip("^")
        if sha in PR_SHAS:
            final_lineno = m.group("final_lineno")
            changed_lines.add(f"{path}:{final_lineno}")

with open(os.environ["CHANGED_LINES_FILE"], "w") as f:
    for item in sorted(changed_lines):
        f.write(item + "\n")
'

echo "Changed lines:"
cat "$CHANGED_LINES_FILE"
echo

########################################################################
# Filter Ruff output: keep only diagnostics whose "fpath:lineno" is in changed_lines
########################################################################
echo "Ruff issues on lines last-touched by this branch:"

python3 -c '
import os, sys

CHANGED_LINES = [
    x.strip()
    for x in open(os.environ["CHANGED_LINES_FILE"], "r")
    if x.strip()
]

RUFF_OUT = [
    x.strip()
    for x in open(os.environ["RUFF_OUT"], "r")
    if x.strip()
]

keepers = []

# note - there are probably more changed lines than ruff errors
for fpath_lineno in CHANGED_LINES:
    for ruff_line in RUFF_OUT:
        if ruff_line.startswith(fpath_lineno + ":"):
            keepers.append(ruff_line)

if keepers:
    for line in keepers:
        print("::error::" + line)
    print(f"::error::Found {len(keepers)} errors on lines touched by this branch.")
    sys.exit(1)
else:
    print("::info::No errors on lines touched by this branch.")
'
