#!/bin/bash
set -euo pipefail
set -x

################################################################################
# Usage: determine-reusable-ref.sh <owner>/<repo>/.github/workflows/<file>.yml
################################################################################

target="$1"
# escape dots for grep -E
target_re="${target//./\\.}"

################################################################################
# Get the calling workflow's path (yaml) -- we already checked out this repo

# 1 -> WIPACrepo/some-repo/.github/workflows/ci.yml@refs/heads/main
echo "$GITHUB_WORKFLOW_REF"

# 2 -> WIPACrepo/some-repo/.github/workflows/ci.yml
caller_ref="${GITHUB_WORKFLOW_REF%%@*}" # drop everything after "@"

# 3 -> .github/workflows/ci.yml
caller_wf_path=".github/workflows/${caller_ref##*/.github/workflows/}" # drop root

################################################################################
# Parse that workflow (yaml) for the target workflow ref -- AKA the reusable workflow

# 4 -> WIPACrepo/wipac-dev-workflows/.github/workflows/lint-python.yml@v4.2
here_full="$(grep -oE "${target_re}@[^[:space:]]+" "$caller_wf_path" | head -n 1)"
# 5 -> v4.2
here_ref="${here_full##*@}" # grab what's after "@"
echo "here_ref=${here_ref}" >>"$GITHUB_OUTPUT"
