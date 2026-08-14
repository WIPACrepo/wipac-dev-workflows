# wipac-dev-workflows
Common Reusable GitHub Actions Workflows

## Available workflows

All workflows exist in [.github/workflows](.github/workflows/)

* `lint-python.yml`: Somewhat opinionated python linting, though you're able to customize it in your `pyproject.toml`.
* `tag-and-release.yml`: Use for creating releases on commits to your main branch.
* `image-publish.yml`: Use for publishing containers. Automatically builds x86 and arm variants, and can push to CVMFS.

See markdown files next to the yaml for examples and full details.

## Background details.

See https://docs.github.com/en/actions/sharing-automations/reusing-workflows#calling-a-reusable-workflow
