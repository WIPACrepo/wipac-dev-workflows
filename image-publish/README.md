# WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml

This GitHub Actions workflow builds and pushes Docker images to Docker Hub or GitHub Container Registry (GHCR), and optionally requests Singularity image builds or removals on CVMFS.

## Inputs

### Required

| Name    | Description                                                                                                                                                                                                                                                           |
|---------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `image` | Fully qualified Docker image name with optional registry prefix.<br>⚠️ **Do not include a tag or digest.** ⚠️<br>Examples: `ghcr.io/foo/bar`, `foo/bar` (Docker Hub)                                                                                                  |
| `mode`  | What to do:<br>- `BUILD` – Build and publish Docker image on registry<br>- `CVMFS_BUILD` – `BUILD`, then request CVMFS to build/persist it<br>- `CVMFS_REMOVE` – Remove Singularity image(s) from CVMFS<br>- `CVMFS_REMOVE_THEN_BUILD` – Remove then rebuild on CVMFS |

#### Mode Reference

| Mode                      | CVMFS Remove | Docker Build+Publish | CVMFS Build+Publish |
|---------------------------|--------------|----------------------|---------------------|
| `BUILD`                   |              | ✅                    |                     |
| `CVMFS_BUILD`             |              | ✅ (1st)              | ✅ (2nd)             |
| `CVMFS_REMOVE`            | ✅            |                      |                     |
| `CVMFS_REMOVE_THEN_BUILD` | ✅ (1st)      | ✅ (2nd)              | ✅ (3rd)             |

### Optional

> NOTE:
>
> Many input attributes only apply to certain `mode`-based use cases. However, by design, any irrelevant input attributes for a given use case will be ignored. This allows workflows to be flexible, by only including one call to the workflow, with logic around `mode`. See the workflow snippet in the [Example Usage section](#example-usage).

#### If interacting with CVMFS

| Name                | Required                          | Description                                                                                  |
|---------------------|-----------------------------------|----------------------------------------------------------------------------------------------|
| `cvmfs_dest_dir`    | ✅, if using CVMFS                 | CVMFS destination directory for Singularity images                                           |
| `cvmfs_remove_tags` | ⚠️, only if removing CVMFS images | Newline-delimited list of image **tags** to remove from CVMFS (e.g., `latest`, `main-[SHA]`) |

_All CVMFS Singularity images builds are handled by [`WIPACrepo/cvmfs-actions`](https://github.com/WIPACrepo/cvmfs-actions) and listed in its [docker_images.txt](https://github.com/WIPACrepo/cvmfs-actions/blob/main/docker_images.txt)_.

#### Miscellaneous Build Configuration

| Name                  | Required | Description                                                                          |
|-----------------------|----------|--------------------------------------------------------------------------------------|
| `free_disk_space`     | no       | `true` to make space on GitHub runner before building image                          |
| `build_platforms_csv` | no       | Target build platforms. Default: `linux/amd64,linux/arm64`<br>Example: `linux/arm64` |

## Secrets

Depending on the `mode`, secret(s) may be required:

#### If using DockerHub

| Name                | Required                      | Description         |
|---------------------|-------------------------------|---------------------|
| `registry_username` | ✅, if building for Docker Hub | Docker Hub username |
| `registry_token`    | ✅, if building for Docker Hub | Docker Hub token    |

#### If using the GitHub Container Registry (ghcr.io)

| Name             | Required                     | Description                                    |
|------------------|------------------------------|------------------------------------------------|
| `registry_token` | ✅, if building for `ghcr.io` | GitHub token for authenticating with `ghcr.io` |

#### If interacting with CVMFS

| Name                 | Required          | Description                                                                                                                                  |
|----------------------|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `cvmfs_github_token` | ✅, if using CVMFS | GitHub PAT used to interact with  [`WIPACrepo/build-singularity-cvmfs-action`](https://github.com/WIPACrepo/build-singularity-cvmfs-action/) |

## Example Usage

Here are a few examples, out of many possible configurations.

### Static/Single Mode

Build for Docker Hub only:

```yaml
jobs:
  image-publish:
    uses: WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml@v...
    with:
      image: myorg/myimage
      mode: BUILD
    secrets:
      registry_username: ${{ secrets.DOCKERHUB_USERNAME }}
      registry_token: ${{ secrets.DOCKERHUB_TOKEN }}
```

Build for ghcr.io + CVMFS:

```yaml
jobs:
  image-publish:
    uses: WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml@v...
    with:
      image: ghcr.io/myorg/myrepo
      mode: CVMFS_BUILD
      cvmfs_dest_dir: myorg
    secrets:
      registry_token: ${{ secrets.GITHUB_TOKEN }}
      cvmfs_github_token: ${{ secrets.CVMFS_PAT }}
```

### Dynamic/Flexible Mode

Build and/or remove for ghcr.io + CVMFS:

```yaml
jobs:
  determine-mode:
    runs-on: ubuntu-latest
    outputs:
      mode: ${{ steps.set.outputs.mode }}
    steps:
      - name: Determine mode
        id: set
        run: |
          if [[ ... ]]; then
            echo "mode=CVMFS_REMOVE_THEN_BUILD" >> "$GITHUB_OUTPUT"
          elif [[ ... ]]; then
            echo "mode=CVMFS_REMOVE" >> "$GITHUB_OUTPUT"
          else
            echo "mode=CVMFS_BUILD" >> "$GITHUB_OUTPUT"
          fi

  image-publish:
    needs: [ determine-mode, ... ]
    uses: WIPACrepo/wipac-dev-workflows/image-publish/workflow.yml@v...
    with:
      image: ghcr.io/myrepo/myimage
      mode: ${{ needs.determine-mode.outputs.mode }}
      cvmfs_dest_dir: myorg/myrepo
      cvmfs_remove_tags: '${{ github.ref_name }}-[SHA]'
    secrets:
      registry_token: ${{ secrets.GITHUB_TOKEN }}
      cvmfs_github_token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}

```
