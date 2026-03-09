# GHA Reusable Workflow: `lint-python.yml`

_Source: [WIPACrepo/wipac-dev-workflows/.github/workflows/lint-python.yml](https://github.com/WIPACrepo/wipac-dev-workflows/blob/main/.github/workflows/lint-python.yml)_

This GitHub Actions **reusable workflow** performs Python linting and type-checking for a project. It:

* Runs `mypy` across a provided Python version matrix.
* Runs `ty` across a provided Python version matrix.
* Runs repo-wide `ruff`, while respecting the repo's Ruff config.
* Checks for legacy config and prompts migration:
    * `flake8` → `ruff`
    * `mypy` → `ty`
* Runs a stricter `ruff-modernize` job on **non-default branches only**, limited to branch-touched lines.

This workflow currently provides:

* **`mypy`** runs the pre-existing mypy GHA package `WIPACrepo/wipac-dev-mypy-action` across the provided Python version matrix.
* **`config-checks`** enforces migration away from legacy config:
    * fails if `flake8` config exists without `ruff` config
    * fails if `mypy` config exists without `ty` config
    * intended to push repos toward:
        * `flake8` → `ruff`
        * `mypy` → `ty`
* **`ty`** runs across the provided Python version matrix and emits GitHub-format diagnostics.
* **`ruff`** runs repo-wide, respects the repo's Ruff config, and additionally includes configurable McCabe complexity (`C901`) and max statements (`PLR0915`) — similar to `WIPACrepo/wipac-dev-flake8-action`.
* **`ruff-modernize`** helps repos adopt stricter Ruff modernization rules on new work without forcing the entire repo to comply immediately:
    * runs only on non-default branches
    * applies stricter Ruff rules only to branch-touched lines, plus optional surrounding context (configurable)

---

## Inputs

### Required

| Name             | Description                                                                                                               |
|------------------|---------------------------------------------------------------------------------------------------------------------------|
| `default-branch` | Your repo's default branch (e.g., `main`).                                                                                |
| `py-matrix-json` | The JSON string of the matrix of Python versions to lint against.<br>HINT: Use `${{ needs.py-versions.outputs.matrix }}`. |

### Optional

| Name                                 | Description                                                                                                                                                                                    |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `max-complexity`                     | The max allowed McCabe complexity value per function.<br>`<10`: easier to understand<br>`10-15`: medium complexity (ideal range)<br>`>15`: harder to understand and maintain<br>Default: `15`. |
| `max-statements`                     | The max number of statements per function.<br>Default: `50`.                                                                                                                                   |
| `ruff-modernize-changed-line-radius` | **USED BY `ruff-modernize` — ONLY RUNS ON NON-DEFAULT BRANCHES**<br>How many lines on each side of the branch's changed lines to pull in for Ruff.<br>Default: `2`.                            |
| `ruff-modernize-rules`               | **USED BY `ruff-modernize` — ONLY RUNS ON NON-DEFAULT BRANCHES**<br>Which Ruff rules to lint for branch-touched lines (stricter than the repo-wide job).<br>Default: `"I,UP,FA"`.              |

---

## Secrets

None.

---

## Example Usage

### Minimal Configuration

```yaml
jobs:

  py-versions: # see WIPACrepo/wipac-dev-py-versions-action
    ...

  ...

  lint-python:
    needs: [ py-versions ]
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/lint-python.yml@...
    with:
      default-branch: ${{ github.event.repository.default_branch }}
      py-matrix-json: ${{ needs.py-versions.outputs.matrix }}  # ["3.10", ...] 
```

### Python Project with Custom Ruff Settings

```yaml
jobs:

  py-versions: # see WIPACrepo/wipac-dev-py-versions-action
    ...

  ...

  lint-python:
    needs: [ py-versions, ... ]
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/lint-python.yml@v...
    with:
      default-branch: ${{ github.event.repository.default_branch }}
      py-matrix-json: ${{ needs.py-versions.outputs.matrix }}
      max-complexity: 11
      max-statements: 65
```

### Python Project with Custom `ruff-modernize` Settings

```yaml
jobs:

  py-versions: # see WIPACrepo/wipac-dev-py-versions-action
    ...

  ...

  lint-python:
    needs: [ py-versions, ... ]
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/lint-python.yml@v...
    with:
      default-branch: ${{ github.event.repository.default_branch }}
      py-matrix-json: ${{ needs.py-versions.outputs.matrix }}
      ruff-modernize-changed-line-radius: 0
      ruff-modernize-rules: UP
```
