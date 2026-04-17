#!/bin/bash
set -euo pipefail
set -x

################################################################################
# Usage: get-here-ref.sh.sh <owner>/<repo>/.github/workflows/<file>.yml
################################################################################

# check args
if [[ $# -lt 1 ]]; then
    echo "::error::missing required arg: <owner>/<repo>/.github/workflows/<file>.yml"
    exit 2
fi
target="$1"
if [[ ! $target =~ ^[^/]+/[^/]+/\.github/workflows/[^/]+\.yml$ ]]; then
    echo "::error::target must look like <owner>/<repo>/.github/workflows/<file>.yml; got: $target"
    exit 2
fi

# check required env vars
if [[ -z ${GITHUB_WORKFLOW_REF:-} ]]; then
    echo "::error::GITHUB_WORKFLOW_REF is not set"
    exit 2
fi
if [[ -z ${GITHUB_OUTPUT:-} ]]; then
    echo "::error::GITHUB_OUTPUT is not set"
    exit 2
fi

################################################################################
# Get the calling workflow's path (yaml) -- we already checked out this repo

# 1 -> WIPACrepo/some-repo/.github/workflows/ci.yml@refs/heads/main
echo "$GITHUB_WORKFLOW_REF"

# 2 -> WIPACrepo/some-repo/.github/workflows/ci.yml
caller_ref="${GITHUB_WORKFLOW_REF%%@*}" # drop everything after "@"

# 3 -> .github/workflows/ci.yml
caller_wf_path=".github/workflows/${caller_ref##*/.github/workflows/}" # drop root
if [[ ! -f $caller_wf_path ]]; then
    echo "::error file=${caller_wf_path}::caller workflow file not found (did actions/checkout run?)"
    exit 1
fi

################################################################################
# Parse that workflow (yaml) for the target workflow ref -- AKA the reusable workflow

# escape dots for grep -E
target_re="${target//./\\.}"

# 4 -> WIPACrepo/wipac-dev-workflows/.github/workflows/lint-python.yml@v4.2
here_full="$(grep -oE "${target_re}@[^[:space:]]+" "$caller_wf_path" | head -n 1 || true)"
if [[ -z $here_full ]]; then
    echo "::error file=${caller_wf_path}::could not find '${target}@<ref>' in caller workflow"
    exit 1
fi

# 5 -> v4.2
here_ref="${here_full##*@}" # grab what's after "@"
echo "here_ref=${here_ref}" >>"$GITHUB_OUTPUT"
