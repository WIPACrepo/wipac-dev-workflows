"""Filter Ruff output to only include diagnostics for lines touched by this branch."""

import os
import re
import subprocess
import sys

# env vars
PR_SHAS = set(open(os.environ["PR_SHAS_FILE"]).read().split())
CHANGED_FILES = [x.strip() for x in open(os.environ["CHANGED_FILES_FILE"]) if x.strip()]
RUFF_OUT = [x.strip() for x in open(os.environ["RUFF_OUT"]) if x.strip()]
CONTEXT_LINE_RADIUS = int(os.environ.get("CONTEXT_LINE_RADIUS", 0))


# regexes
GIT_BLAME_LINE_PORCELAIN_HEADER_RE = re.compile(
    r"^(?P<sha>[0-9a-f]{40})\s+\d+\s+(?P<final_lineno>\d+)\b"
)
RUFF_FILE_LINENO_RE = re.compile(r"^(?:Error:\s+)?(?P<path>[^:]+):(?P<lineno>\d+):")


def get_changed_file_linenos() -> dict[str, set[int]]:
    """Return the files mapped to line-numbers last-touched by this branch."""
    changed_file_linenos: dict[str, set[int]] = {}

    for path in CHANGED_FILES:
        txt = subprocess.check_output(
            ["git", "blame", "--line-porcelain", os.environ["HEAD_SHA"], "--", path],
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
                if m.group("sha") in PR_SHAS:
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
            elif CONTEXT_LINE_RADIUS > 0 and any(
                x in changed_file_linenos[path]
                for x in range(
                    lineno - CONTEXT_LINE_RADIUS, lineno + CONTEXT_LINE_RADIUS + 1
                )
            ):
                keepers.append(ruff_line)

    return keepers


def main():
    """Main."""
    # 1: get changed lines
    changed_file_linenos = get_changed_file_linenos()
    print("Changed lines:")
    for p in sorted(changed_file_linenos):
        for n in sorted(changed_file_linenos[p]):
            print(f"{p}:{n}")
    print()

    # 2: filter ruff output for only those lines
    keepers = filter_ruff_out(changed_file_linenos)
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
