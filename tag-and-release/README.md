# WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml

This GitHub Actions **reusable workflow** performs tagging, building, and releasing of a Python package. It:

- Determines the next version based on conventional commit history.
- Builds the package (`dist/`).
- Always creates a GitHub Release.
- Optionally publishes to PyPI.
- Optionally downloads artifacts and includes them in the GitHub Release.

---

## Inputs

### Required

| Name             | Description                                   |
|------------------|-----------------------------------------------|
| `python-version` | Python version used for building the package. |

### Optional

| Name                | Description                                                                                                                                            |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| `release-artifacts` | Newline-separated list of artifact names to download and attach to the GitHub Release.<br>Each will be included under `release-artifacts/<name>/**/*`. |
| `publish-to-pypi`   | Set to `true` to publish the package to [PyPI](https://pypi.org/).<br>Default: `false`.                                                                |

---

## Secrets

| Name                    | Required               | Description                                                    |
|-------------------------|------------------------|----------------------------------------------------------------|
| `PERSONAL_ACCESS_TOKEN` | ✅ Always               | GitHub token for authenticating CLI and downloading artifacts. |
| `PYPI_TOKEN`            | ✅ if `publish-to-pypi` | API token for uploading the package to PyPI.                   |

---

## Example Usage

```yaml
jobs:
  tag-and-release:
    # only run on main/default
    if: format('refs/heads/{0}', github.event.repository.default_branch) == github.ref
    needs: [ ... ]
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/tag-and-release.yml@v...
    with:
      python-version: "${{ fromJSON(needs.py-versions.outputs.matrix)[0] }}"
      release-artifacts: |
        py-dependencies-logs
      publish-to-pypi: true
    secrets:
      PERSONAL_ACCESS_TOKEN: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
      PYPI_TOKEN: ${{ secrets.PYPI_TOKEN }}
```
