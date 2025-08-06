# WIPACrepo/wipac-dev-workflows/.github/workflows/image-publish.yml

This GitHub Actions workflow builds and pushes Docker images to Docker Hub, GitHub Container Registry (GHCR), Harbor, or other container registries, and optionally requests Singularity image builds or removals on CVMFS.

## Inputs

### Basic Inputs

| Name              | Required (Default) | Description                                                                                                                                                                                                                                                           |
|-------------------|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `image_registry`  | no (`ghcr.io`)     | The target image's container registry hostname (no namespace).<br>Examples: `ghcr.io`, `docker.io`, `harbor.icecube.aq`                                                                                                                                               |
| `image_namespace` | ✅                  | The target image's namespace or project path in the registry (may include `/`).<br>Examples: `foo`, `foo/bar`, `myproject`                                                                                                                                            |
| `image_name`      | ✅                  | The target image's name (only the name – no registry, no namespace, no tag, no digest).<br>Examples: `myimage`, `scanner`                                                                                                                                             |
| `mode`            | ✅                  | What to do:<br>- `BUILD` – Build and publish Docker image on registry<br>- `CVMFS_BUILD` – `BUILD`, then request CVMFS to build/persist it<br>- `CVMFS_REMOVE` – Remove Singularity image(s) from CVMFS<br>- `CVMFS_REMOVE_THEN_BUILD` – Remove then rebuild on CVMFS |

#### Mode Reference

| Mode                      | CVMFS Remove | Docker Build+Publish | CVMFS Build+Publish |
|---------------------------|--------------|----------------------|---------------------|
| `BUILD`                   |              | ✅                    |                     |
| `CVMFS_BUILD`             |              | ✅ (1st)              | ✅ (2nd)             |
| `CVMFS_REMOVE`            | ✅            |                      |                     |
| `CVMFS_REMOVE_THEN_BUILD` | ✅ (1st)      | ✅ (2nd)              | ✅ (3rd)             |

### Additional Inputs

> NOTE:
>
> Many input attributes only apply to certain `mode`-based use cases. However, by design, any irrelevant input attributes for a given use case will be ignored. This allows workflows to be flexible, by only including one call to the workflow, with logic around `mode`. See the workflow snippet in the [Example Usage section](#example-usage).

#### If interacting with CVMFS

| Name                | Required                          | Description                                                                                  |
|---------------------|-----------------------------------|----------------------------------------------------------------------------------------------|
| `cvmfs_dest_dir`    | ✅, if using CVMFS                 | CVMFS destination directory for Singularity images                                           |
| `cvmfs_remove_tags` | ⚠️, only if removing CVMFS images | Newline-delimited list of image **tags** to remove from CVMFS (e.g., `latest`, `main-[SHA]`) |

*All CVMFS Singularity images builds are handled by [`WIPACrepo/cvmfs-actions`](https://github.com/WIPACrepo/cvmfs-actions) and listed in its [docker\_images.txt](https://github.com/WIPACrepo/cvmfs-actions/blob/main/docker_images.txt)*.

#### Miscellaneous Build Configuration

| Name                   | Required | Description                                                                                                                                                                                                                                                  |
|------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `free_disk_space`      | no       | `true` to make space on GitHub runner before building image                                                                                                                                                                                                  |
| `build_platforms_csv`  | no       | Target build platforms. Default: `linux/amd64,linux/arm64`<br>Example: `linux/arm64`                                                                                                                                                                         |
| `publish_tag_override` | no       | Use this tag **instead of auto-generated tags**.<br>Useful with `workflow_dispatch` to override tags like `dev`, `test`, or `unstable`. Example: `build_tag_override: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.my_tag \|\| '' }}` |

## Secrets

Depending on the `mode`, secret(s) may be required:

### Container Registry Authentication

| Name                | Required                                        | Description                                | Notes                                                                                                                |
|---------------------|-------------------------------------------------|--------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `registry_username` | ✅, if registry requires authentication username | Username for the container registry.       | Ignored for `ghcr.io` (uses `${{ github.actor }}`).                                                                  |
| `registry_token`    | ✅, if registry requires authentication          | Token/password for the container registry. | Not needed for `ghcr.io` (defaults to `${{ secrets.GITHUB_TOKEN }}`), unless publishing to a third-party repository. |

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

  ...

  image-publish:
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/image-publish.yml@v...
    with:
      image_registry: docker.io
      image_namespace: myorg
      image_name: myimage
      mode: BUILD
    secrets:
      registry_username: ${{ secrets.DOCKERHUB_USERNAME }}
      registry_token: ${{ secrets.DOCKERHUB_TOKEN }}
```

Build for `ghcr.io` + CVMFS:

```yaml
jobs:

  ...

  image-publish:
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/image-publish.yml@v...
    with:
      image_registry: ghcr.io
      image_namespace: myorg
      image_name: myrepo
      mode: CVMFS_BUILD
      cvmfs_dest_dir: myorg
    secrets:
      cvmfs_github_token: ${{ secrets.CVMFS_PAT }}
```

Build for Harbor registry:

```yaml
jobs:

  ...

  image-publish:
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/image-publish.yml@v...
    with:
      image_registry: harbor.icecube.aq
      image_namespace: icecube-project
      image_name: scanner
      mode: BUILD
    secrets:
      registry_username: ${{ secrets.HARBOR_USERNAME }}
      registry_token: ${{ secrets.HARBOR_TOKEN }}
```

### Dynamic/Flexible Mode

Build and/or remove for ghcr.io + CVMFS:

```yaml
jobs:

  ...

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
    uses: WIPACrepo/wipac-dev-workflows/.github/workflows/image-publish.yml@v...
    with:
      image_registry: ghcr.io
      image_namespace: myorg
      image_name: myrepo
      mode: ${{ needs.determine-mode.outputs.mode }}
      cvmfs_dest_dir: myorg/myrepo
      cvmfs_remove_tags: '${{ github.ref_name }}-[SHA]'
    secrets:
      cvmfs_github_token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
```
