# WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml

This GitHub Actions **reusable workflow** performs tagging and releasing of a project, with optional Python package building and PyPI publishing. It:

* Determines the next version based on conventional commit history.
* **Automatically builds the package if `project-type` is `python`** (`dist/`).
* Always creates a GitHub Release.
* Optionally publishes to PyPI (Python-only).
* Optionally downloads artifacts and includes them in the GitHub Release.

---

## Inputs

### Required

| Name           | Description                                                                                                             |
|----------------|-------------------------------------------------------------------------------------------------------------------------|
| `project-type` | Project type. Only `'python'` triggers an automatic build; all others should provide artifacts via `release-artifacts`. |

### Optional

| Name                | Description                                                                                                                                                                                                                                                                                   |
|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `python-version`    | Python version used for building the package. **Required** if `project-type` is `'python'`.                                                                                                                                                                                                   |
| `release-artifacts` | Newline-separated list of artifact names to download and attach to the GitHub Release. Each will be included under `release-artifacts/<name>/**/*`.                                                                                                                                           |
| `publish-to-pypi`   | If `true` and `project-type` is `'python'`, publish the package to [PyPI](https://pypi.org/). Default: `false`.                                                                                                                                                                               |
| `version-style`     | Versioning style for next-version calc. Example: `'X.Y.Z'` (default), `'X.Y'`.                                                                                                                                                                                                                |
| `ignore-paths`      | Base newline-separated globs to ignore when determining the next version.<br>See [tag-and-release.yml](./tag-and-release.yml) for defaults.                                                                                                                                                   |
| `more-ignore-paths` | Extra newline-separated globs to append to `ignore-paths`. Useful for extending without duplicating defaults.<br>_Note: Prepend `!` if you want to make sure a path is **not ignored**, e.x. `!.github/workflows/**`, `!**/README.md`. Pattern ordering does not matter._ <br> Default: `""`. |

---

## Secrets

| Name         | When to Use                                                   | Description                                  |
|--------------|---------------------------------------------------------------|----------------------------------------------|
| `TOKEN`      | if you want to trigger GHA workflows from the `git tag` event | A token for the repo that can push tags.     |
| `PYPI_TOKEN` | if `publish-to-pypi` and `project-type` is `'python'`         | API token for uploading the package to PyPI. |

---

## Example Usage

### Python Project

```yaml
jobs:

  py-versions: # see WIPACrepo/wipac-dev-py-versions-action
    ...

  ...

  tag-and-release:
    # only run on main/default branch
    if: format('refs/heads/{0}', github.event.repository.default_branch) == github.ref
    needs: [ py-versions, ... ]
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml@v...
    permissions: # for GITHUB_TOKEN
      contents: write
    with:
      project-type: python
      python-version: "${{ fromJSON(needs.py-versions.outputs.matrix)[0] }}"
      release-artifacts: |
        py-dependencies-logs
      publish-to-pypi: true
    secrets:
      TOKEN: ${{ secrets.PERSONAL_ACCESS_TOKEN }}  # trigger tag-event gha workflows
      PYPI_TOKEN: ${{ secrets.PYPI_TOKEN }}
```

### Other Language Project

```yaml
jobs:

  ...

  tag-and-release:
    # only run on main/default branch
    if: format('refs/heads/{0}', github.event.repository.default_branch) == github.ref
    needs: [ build-job ] # where your project was built and artifacts were uploaded
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml@v...
    permissions: # for GITHUB_TOKEN
      contents: write
    with:
      project-type: rust
      release-artifacts: |
        build-logs
        compiled-rust-proj
      more-ignore-paths: |
        rust-docs/**
```

```yaml
jobs:

  ...

  tag-and-release:
    # only run on main/default
    if: format('refs/heads/{0}', github.event.repository.default_branch) == github.ref
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml@...
    permissions: # for GITHUB_TOKEN
      contents: write
    with:
      project-type: gha-workflow
      version-style: 'X.Y'
      more-ignore-paths: |
        !.github/workflows/**
```
