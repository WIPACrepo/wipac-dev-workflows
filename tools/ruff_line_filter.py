"""Filter Ruff output to only include diagnostics for lines touched by this branch."""

import os
import pprint
import re
import subprocess
import sys

# env vars
HEAD_SHA = os.environ["HEAD_SHA"]
MERGE_BASE = os.environ["MERGE_BASE"]
CHANGED_LINE_RADIUS = int(os.environ.get("CHANGED_LINE_RADIUS", 0))
print(f"{CHANGED_LINE_RADIUS=}")
# -- files
CHANGED_FILES = [x.strip() for x in open(os.environ["CHANGED_FILES_FILE"]) if x.strip()]
RUFF_OUT = [x.strip() for x in open(os.environ["RUFF_OUT"]) if x.strip()]


# regexes
GIT_BLAME_LINE_PORCELAIN_HEADER_RE = re.compile(
    r"^(?P<sha>[0-9a-f]{40})\s+\d+\s+(?P<final_lineno>\d+)\b"
)
RUFF_FILE_LINENO_RE = re.compile(r"^(?:Error:\s+)?(?P<path>[^:]+):(?P<lineno>\d+):")


def get_changed_file_linenos(branch_shas: set[str]) -> dict[str, set[int]]:
    """Return the files mapped to line-numbers last-touched by this branch."""
    changed_file_linenos: dict[str, set[int]] = {}

    for path in CHANGED_FILES:
        txt = subprocess.check_output(
            ["git", "blame", "--line-porcelain", HEAD_SHA, "--", path],
            text=True,
        )
        for line in txt.splitlines():
            # Ex:
            # ...
            # 1c4bc039eb3e63c04d623be7281a58dd4677db47 5 5
            # author Ric Evans
            # <other fields>
            # filename lta/bundler.py
            #
            # 46db3ed19651652e6b875dffd1b15533f030d9f2 4 6 1
            # author Ric Evans
            # <other fields>
            # filename lta/bundler.py
            #         import asyncio
            # 46db3ed19651652e6b875dffd1b15533f030d9f2 7 7 1
            # ...
            if m := GIT_BLAME_LINE_PORCELAIN_HEADER_RE.match(line):
                if m.group("sha") in branch_shas:
                    final_lineno = int(m.group("final_lineno"))
                    try:
                        changed_file_linenos[path].add(final_lineno)
                    except KeyError:
                        changed_file_linenos[path] = {final_lineno}

    return changed_file_linenos


def filter_ruff_out(changed_file_linenos: dict[str, set[int]]) -> list[str]:
    """Filter Ruff output to only include diagnostics for lines touched by this branch."""
    keepers = []

    for ruff_line in RUFF_OUT:
        # Ex:
        # lta/lta_cmd.py:11:8: F401 `copy` imported but unused
        if m := RUFF_FILE_LINENO_RE.match(ruff_line):
            path = m.group("path")
            if path not in changed_file_linenos:
                continue
            lineno = int(m.group("lineno"))
            # is this line touched by this branch?
            if lineno in changed_file_linenos[path]:
                keepers.append(ruff_line)
            # else, is this line near a line touched by this branch?
            elif CHANGED_LINE_RADIUS > 0 and any(
                x in changed_file_linenos[path]
                for x in range(
                    lineno - CHANGED_LINE_RADIUS, lineno + CHANGED_LINE_RADIUS + 1
                )
            ):
                keepers.append(ruff_line)

    return keepers


def main():
    """Main."""
    # 0. Get all the SHAs of the commits in this branch
    branch_shas = set(
        subprocess.check_output(
            ["git", "rev-list", f"{MERGE_BASE}..{HEAD_SHA}"],
            text=True,
        ).splitlines()
    )
    print("Commit SHAs for this Branch:")
    pprint.pprint(branch_shas)
    print()

    # 1: Get changed lines
    changed_file_linenos = get_changed_file_linenos(branch_shas)
    print("Changed lines:")
    pprint.pprint(changed_file_linenos)
    print()

    # 2: Filter ruff output for only those lines -> print for GitHub Actions
    keepers = filter_ruff_out(changed_file_linenos)
    print(
        f"Ruff errors on lines touched by this branch"
        + (
            ":"
            if not CHANGED_LINE_RADIUS
            else f" (or within {CHANGED_LINE_RADIUS} lines of touched lines):"
        )
    )
    if keepers:
        for line in keepers:
            print("::error::" + line)
        print(f"Found {len(keepers)} errors.")
        print(
            f"::notice::You can run 'ruff check --select {os.environ['RUFF_SELECT']}"
            " (--fix|--fix-only) [PATHS]' to auto-fix *all* issues in file(s)."
        )
        sys.exit(1)
    else:
        print("::info::No ruff errors.")


if __name__ == "__main__":
    main()
