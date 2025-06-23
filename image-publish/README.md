# WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml

This GitHub Actions workflow builds and pushes Docker images to Docker Hub or GitHub Container Registry (GHCR), and optionally requests Singularity image builds or removals on CVMFS.

## Inputs

### Required

| Name     | Description                                                                                                                                                                                                                                                           |
|----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `image`  | Fully qualified Docker image name with optional registry prefix.<br>⚠️ **Do not include a tag or digest.** ⚠️<br>Examples: `ghcr.io/foo/bar`, `foo/bar` (Docker Hub)                                                                                                  |
| `action` | What to do:<br>- `BUILD` – Build and publish Docker image on registry<br>- `CVMFS_BUILD` – `BUILD`, then request CVMFS to build/persist it<br>- `CVMFS_REMOVE` – Remove Singularity image(s) from CVMFS<br>- `CVMFS_REMOVE_THEN_BUILD` – Remove then rebuild on CVMFS |

#### Action Reference

| Action                    | CVMFS Remove | Docker Build+Publish | CVMFS Build+Publish |
|---------------------------|--------------|----------------------|---------------------|
| `BUILD`                   |              | ✅                    |                     |
| `CVMFS_BUILD`             |              | ✅ (1st)              | ✅ (2nd)             |
| `CVMFS_REMOVE`            | ✅            |                      |                     |
| `CVMFS_REMOVE_THEN_BUILD` | ✅ (1st)      | ✅ (2nd)              | ✅ (3rd)             |

### Optional

> NOTE:
>
> Many input attributes only apply to certain `action`-based use cases. However, by design, any irrelevant input attributes for a given use case will be ignored. This allows workflows to be flexible, by having only one `uses: WIPACRepo/wipac-dev-publish-image-action` section, with logic around `action`. See the workflow snippet in the [Example Usage section](#example-usage).

#### If using DockerHub

| Name                 | Required                      | Description         |
|----------------------|-------------------------------|---------------------|
| `dockerhub_username` | ✅, if building for Docker Hub | Docker Hub username |
| `dockerhub_token`    | ✅, if building for Docker Hub | Docker Hub token    |

#### If using the GitHub Container Registry (ghcr.io)

| Name         | Required                     | Description                                    |
|--------------|------------------------------|------------------------------------------------|
| `ghcr_token` | ✅, if building for `ghcr.io` | GitHub token for authenticating with `ghcr.io` |

#### If interacting with CVMFS

| Name                | Required                          | Description                                                                                                                                  |
|---------------------|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `gh_cvmfs_token`    | ✅, if using CVMFS                 | GitHub PAT used to interact with  [`WIPACrepo/build-singularity-cvmfs-action`](https://github.com/WIPACrepo/build-singularity-cvmfs-action/) |
| `cvmfs_dest_dir`    | ✅, if using CVMFS                 | CVMFS destination directory for Singularity images                                                                                           |
| `cvmfs_remove_tags` | ⚠️, only if removing CVMFS images | Newline-delimited list of image **tags** to remove from CVMFS (e.g., `latest`, `main-[SHA]`)                                                 |

_All CVMFS Singularity images builds are handled by [`WIPACrepo/cvmfs-actions`](https://github.com/WIPACrepo/cvmfs-actions) and listed in its [docker_images.txt](https://github.com/WIPACrepo/cvmfs-actions/blob/main/docker_images.txt)_.

#### Miscellaneous Build Configuration

| Name              | Required | Description                                                             |
|-------------------|----------|-------------------------------------------------------------------------|
| `free_disk_space` | no       | `true` to make space on GitHub runner before building image             |
| `build_platform`  | no       | Target build platform. Default: `linux/amd64`<br>Example: `linux/arm64` |

## Example Usage

Here are a few examples, out of many possible configurations.

### Static/Single Action

Build for Docker Hub only:

```yaml
jobs:
  publish:
    uses: WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml@v...
    with:
      image: myorg/myimage
      action: BUILD
      dockerhub_username: ${{ secrets.DOCKERHUB_USERNAME }}
      dockerhub_token: ${{ secrets.DOCKERHUB_TOKEN }}
```

Build for ghcr.io + CVMFS:

```yaml
jobs:
  publish:
    uses: WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml@v...
    with:
      image: ghcr.io/myrepo/myimage
      action: CVMFS_BUILD
      ghcr_token: ${{ secrets.GITHUB_TOKEN }}
      gh_cvmfs_token: ${{ secrets.CVMFS_PAT }}
      cvmfs_dest_dir: myorg
```

### Dynamic/Flexible Action

Build and/or remove for ghcr.io + CVMFS:

```yaml
jobs:
  determine-action:
    runs-on: ubuntu-latest
    outputs:
      action: ${{ steps.set.outputs.action }}
    steps:
      - name: Determine action
        id: set
        run: |
          if [[ ... ]]; then
            echo "action=CVMFS_REMOVE_THEN_BUILD" >> "$GITHUB_OUTPUT"
          elif [[ ... ]]; then
            echo "action=CVMFS_REMOVE" >> "$GITHUB_OUTPUT"
          else
            echo "action=CVMFS_BUILD" >> "$GITHUB_OUTPUT"
          fi

  publish-or-remove:
    needs: [ determine-action, ... ]
    uses: WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml@v...
    with:
      image: ghcr.io/myrepo/myimage
      action: ${{ needs.determine-action.outputs.action }}
      ghcr_token: ${{ secrets.GITHUB_TOKEN }}
      gh_cvmfs_token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
      cvmfs_dest_dir: myorg/myrepo
      cvmfs_remove_tags: '${{ github.ref_name }}-[SHA]'

```
