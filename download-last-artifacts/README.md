# Download Last Artifacts Action

A reusable composite action that downloads artifacts from the last successful run of a specified GitHub Actions workflow.

## Usage

### Basic Usage

```yaml
- name: Download artifacts from last successful nightly
  uses: ./.github/actions/download-last-artifacts
  with:
    workflow_name: 'new-nightly.yaml'
    github_token: ${{ github.token }}
```

### Download Specific Artifact

```yaml
- name: Download specific artifact
  id: download
  uses: ./.github/actions/download-last-artifacts
  with:
    workflow_name: 'new-nightly.yaml'
    artifact_name: 'container-images'
    download_path: '/tmp/images'
    github_token: ${{ github.token }}

- name: Use downloaded artifacts
  run: |
    echo "Artifacts downloaded to: ${{ steps.download.outputs.artifacts-path }}"
    ls -la ${{ steps.download.outputs.artifacts-path }}
```

### Download from Specific Branch

```yaml
- name: Download artifacts from release branch
  uses: ./.github/actions/download-last-artifacts
  with:
    workflow_name: 'new-nightly.yaml'
    branch: 'release-0.8'
    github_token: ${{ github.token }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `workflow_name` | The workflow file name (e.g., `new-nightly.yaml`) | Yes | - |
| `branch` | Branch to filter workflow runs by | No | `main` |
| `artifact_name` | Specific artifact name to download (leave empty for all) | No | `` (all) |
| `download_path` | Path to download artifacts to | No | `./artifacts` |
| `github_token` | GitHub token for API access | Yes | - |

## Outputs

| Output | Description |
|--------|-------------|
| `run-id` | The workflow run ID that artifacts were downloaded from |
| `artifacts-path` | Path where artifacts were downloaded |

## Examples

### Using with Kind Cluster

```yaml
- name: Download nightly images
  id: download-images
  uses: ./.github/actions/download-last-artifacts
  with:
    workflow_name: 'new-nightly.yaml'
    artifact_name: 'container-images'
    download_path: '/tmp/images'
    github_token: ${{ github.token }}

- name: Load images into kind
  run: |
    for tar_file in $(find ${{ steps.download-images.outputs.artifacts-path }} -name "*.tar"); do
      kind load image-archive "$tar_file"
    done
```

### Download All Artifacts

```yaml
- name: Download all artifacts from last nightly
  uses: ./.github/actions/download-last-artifacts
  with:
    workflow_name: 'new-nightly.yaml'
    download_path: './all-artifacts'
    github_token: ${{ github.token }}
```

## Notes

- The action uses the GitHub CLI (`gh`) which is pre-installed on GitHub-hosted runners
- Requires a GitHub token with `actions:read` permission
- Only downloads artifacts from the most recent **successful** workflow run
- Artifacts must not be expired (default GitHub retention is 90 days)
