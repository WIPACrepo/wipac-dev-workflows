"""Filter Ruff output to only include diagnostics for lines touched by this branch."""

import os
import re
import subprocess
import sys

# env vars
PR_SHAS = set(open(os.environ["PR_SHAS_FILE"]).read().split())
CHANGED_FILES = [x.strip() for x in open(os.environ["CHANGED_FILES_FILE"]) if x.strip()]
RUFF_OUT = [x.strip() for x in open(os.environ["RUFF_OUT"]) if x.strip()]


# regexes
GIT_BLAME_HEADER_RE = re.compile(
    r"^(?P<sha>\^?[0-9a-f]{40})\s+\d+\s+(?P<final_lineno>\d+)\b"
)


def get_changed_lines() -> set[str]:
    """Return a set of "fpath:lineno" for lines last-touched by this branch."""
    changed_lines = set()

    for path in CHANGED_FILES:
        txt = subprocess.check_output(
            ["git", "blame", "--line-porcelain", os.environ["HEAD_SHA"], "--", path],
            text=True,
        )
        for line in txt.splitlines():
            m = GIT_BLAME_HEADER_RE.match(line)
            if not m:
                continue
            sha = m.group("sha").lstrip("^")
            if sha in PR_SHAS:
                final_lineno = m.group("final_lineno")
                changed_lines.add(f"{path}:{final_lineno}")

    return set(changed_lines)


########################################################################
# Filter Ruff output: keep only diagnostics whose "fpath:lineno" is in changed_lines
########################################################################


def filter_ruff_out(changed_lines: set[str]) -> list[str]:
    """Filter Ruff output to only include diagnostics for lines touched by this branch."""
    keepers = []
    # note - there are probably more changed lines than ruff errors
    for fpath_lineno in changed_lines:
        for ruff_line in RUFF_OUT:
            if ruff_line.startswith(fpath_lineno + ":"):
                keepers.append(ruff_line)

    return keepers


def main():
    """Main."""
    # 1: get changed lines
    changed_lines = get_changed_lines()
    print("Changed lines:")
    for line in sorted(changed_lines):
        print(line)
    print()

    # 2: filter ruff output for only those lines
    keepers = filter_ruff_out(changed_lines)
    print("Ruff issues on lines last-touched by this branch:")
    if keepers:
        for line in keepers:
            print("::error::" + line)
        print(f"::error::Found {len(keepers)} errors on lines touched by this branch.")
        sys.exit(1)
    else:
        print("::info::No errors on lines touched by this branch.")


if __name__ == "__main__":
    main()
