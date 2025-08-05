# WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml

This GitHub Actions **reusable workflow** performs tagging and releasing of a project, with optional Python package building and PyPI publishing. It:

- Determines the next version based on conventional commit history.
- **Automatically builds the package if `project-type` is `python`** (`dist/`).
- Always creates a GitHub Release.
- Optionally publishes to PyPI (Python-only).
- Optionally downloads artifacts and includes them in the GitHub Release.

---

## Inputs

### Required

| Name           | Description                                                                                                         |
|----------------|---------------------------------------------------------------------------------------------------------------------|
| `project-type` | Project type. Only `'python'` triggers an automatic build, all others need to be passed in via `release-artifacts`. |

### Optional

| Name                | Description                                                                                                                                            |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| `python-version`    | Python version used for building the package. Required if `project-type` is `'python'`.                                                                |
| `release-artifacts` | Newline-separated list of artifact names to download and attach to the GitHub Release.<br>Each will be included under `release-artifacts/<name>/**/*`. |
| `publish-to-pypi`   | If `true` and `project-type` is `'python'`, publish the package to [PyPI](https://pypi.org/).<br>Default: `false`.                                     |

---

## Secrets

| Name                    | Required                                                | Description                                                    |
|-------------------------|---------------------------------------------------------|----------------------------------------------------------------|
| `PERSONAL_ACCESS_TOKEN` | ✅ Always                                                | GitHub token for authenticating CLI and downloading artifacts. |
| `PYPI_TOKEN`            | ✅ if `publish-to-pypi` and `project-type` is `'python'` | API token for uploading the package to PyPI.                   |

---

## Example Usage

### Python Project

```yaml
jobs:

  ...

  tag-and-release:
    # only run on main/default branch
    if: format('refs/heads/{0}', github.event.repository.default_branch) == github.ref
    needs: [ ... ]
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml@v...
    with:
      project-type: python
      python-version: "${{ fromJSON(needs.py-versions.outputs.matrix)[0] }}"
      release-artifacts: |
        py-dependencies-logs
      publish-to-pypi: true
    secrets:
      PERSONAL_ACCESS_TOKEN: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
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
    with:
      project-type: rust
      release-artifacts: |
        build-logs
        compiled-rust-proj
    secrets:
      PERSONAL_ACCESS_TOKEN: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
```
