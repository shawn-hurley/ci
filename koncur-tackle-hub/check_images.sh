#!/bin/bash

set -e

REQUIRED_IMAGES=(
    "quay.io/konveyor/tackle2-hub"
    "quay.io/konveyor/tackle2-addon-analyzer"
    "quay.io/konveyor/tackle2-addon-discovery"
    "quay.io/konveyor/tackle2-addon-platform"
    "quay.io/konveyor/c-sharp-provider"
    "quay.io/konveyor/java-external-provider"
    "quay.io/konveyor/generic-external-provider"
)
hub_regex=".*tackle2-hub.*"
addon_regex=".*tackle2-addon-analyzer.*"
addon_discovery=".*tackle2-addon-discovery.*"
addon_platform=".*tackle2-addon-platform.*"
kantra_image_regex=".*kantra.*"
java_provider_image_regex=".*java(-external)?-provider.*"
c_sharp_provider_image_regex=".*c-sharp-provider.*"
generic_provider_image_regex=".*generic(-external)?-provider.*"

echo "Checking for required podman images..."
echo "------------------------------------------------------------"

# Get list of all podman images
IMAGES=$(podman exec koncur-test-control-plane crictl images -o json | jq -r '.[] | map(.repoTags[])' 2>/dev/null)

if [ -z "$IMAGES" ]; then
    echo "No images found in podman."
    echo ""
    echo "Missing images:"
    for img in "${REQUIRED_IMAGES[@]}"; do
        echo "  - $img"
    done
    exit 1
fi

MISSING=()
FOUND=()
FOUND_TAG=""

# Check each required image
for required in "${REQUIRED_IMAGES[@]}"; do
    if echo "$IMAGES" | grep -qi "$required"; then
        MATCHED=$(echo "$IMAGES" | grep -i "$required" | head -n 1)
        FOUND+=("$required: $MATCHED")

        # Extract tag from the first found image
        if [ -z "$FOUND_TAG" ]; then
            FOUND_TAG=$(echo "$MATCHED" | cut -d':' -f2)
            echo "Extracted tag from found image: $FOUND_TAG"
        fi
    else
        MISSING+=("$required")
    fi
done

# Display found images
if [ ${#FOUND[@]} -gt 0 ]; then
    echo "Found images:"
    for img in "${FOUND[@]}"; do
        echo "  ✓ $img"
    done
fi

# Display missing images
if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "Missing images:"
    for img in "${MISSING[@]}"; do
        echo "  ✗ $img"
    done
    echo "------------------------------------------------------------"
    echo "Status: ${#MISSING[@]} image(s) missing"
    echo ""

    if [ -n "$FOUND_TAG" ]; then
        echo "Will re-tag downloaded images to match: $FOUND_TAG"
    fi

    echo "Attempting to download missing images from last successful nightly run..."

    # Find the last successful run of the nightly workflow
    WORKFLOW_RUN=$(gh run list -R=konveyor/ci --workflow=nightly-koncur.yaml --status=success --limit=1 --json databaseId --jq '.[0].databaseId')

    if [ -z "$WORKFLOW_RUN" ]; then
        echo "Error: Could not find a successful nightly workflow run"
        exit 1
    fi

    echo "Found successful workflow run: $WORKFLOW_RUN"

    # Create temp directory for downloads
    TEMP_DIR=$(mktemp -d)
    echo "Using temp directory: $TEMP_DIR"

    DOWNLOAD_SUCCESS=0

    # Download artifacts for missing images
    for img in "${MISSING[@]}"; do
        # Convert image name to artifact naming pattern
        # quay.io/konveyor/kantra -> quay.io_konveyor_kantra
        ARTIFACT_PREFIX="${img//\//_}"

        echo "Downloading artifacts matching: ${ARTIFACT_PREFIX}--*"
        if gh run download -R=konveyor/ci "$WORKFLOW_RUN" --pattern "${ARTIFACT_PREFIX}--*.[0-9][0-9]" --dir "$TEMP_DIR" 3>/dev/null; then
            DOWNLOAD_SUCCESS=1
        else
            echo "Warning: Could not download artifact for $img"
        fi
    done

    # Check if any downloads succeeded
    if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
        echo ""
        echo "Error: No artifacts were successfully downloaded (they may have expired)"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Load downloaded images into podman and optionally re-tag
    echo ""
    echo "Loading downloaded images into podman..."
    for image in $(find "$TEMP_DIR" -type f -name "*.tar"); do
        echo "Loading: ${image}"
        LOADED_IMAGE=$(kind load -i "${image}" | awk '{print $3}')
        echo "Loaded image: $LOADED_IMAGE"

        # Re-tag if we have a tag from found images
        if [ -n "$FOUND_TAG" ] && [ -n "$LOADED_IMAGE" ]; then
            # Extract the repository name (without the tag)
            IMAGE_REPO=$(echo "$LOADED_IMAGE" | cut -d':' -f1)
            NEW_TAG="${IMAGE_REPO}:${FOUND_TAG}"
            echo "Re-tagging to: $NEW_TAG"
            podman tag "$LOADED_IMAGE" "$NEW_TAG"
        fi
        if [[ "$image" =~ $kantra_image_regex ]]; then
            echo "Kantra Image Found Set Env Var: RUNNER_IMG=$NEW_TAG"
            echo "RUNNER_IMG=$NEW_TAG" >> $GITHUB_ENV
        fi
        if [[ "$image" =~ $java_provider_image_regex ]]; then
            echo "Java Provider Image Found Set Env Var: JAVA_PROVIDER_IMG=$NEW_TAG"
            echo "JAVA_PROVIDER_IMG=$NEW_TAG" >> $GITHUB_ENV
        fi
        if [[ "$image" =~ $c_sharp_provider_image_regex ]]; then
            echo "C Sharp Provider Found Set Env Var: CSHARP_PROVIDER_IMG=$NEW_TAG"
            echo "CSHARP_PROVIDER_IMG=$NEW_TAG" >> $GITHUB_ENV
        fi
        if [[ "$image" =~ $generic_provider_image_regex ]]; then
            echo "Generic Provider Image Found Set Env Var: GENERIC_PROVIDER_IMG=$NEW_TAG"
            echo "GENERIC_PROVIDER_IMG=$NEW_TAG" >> $GITHUB_ENV
        fi
        if [[ "$image" =~ $addon_regex ]]; then
            echo "Addon-Analyzer Image Found Set Env Var: ANALYZER_ADDON=$NEW_TAG"
            echo "ANALYZER_ADDON=$NEW_TAG" >> $GITHUB_ENV
        fi
        if [[ "$image" =~ $addon_discovery ]]; then
            echo "Discovery Addon Image Found Set Env Var: DISCOVERY_ADDON=$NEW_TAG"
            echo "DISCOVERY_ADDON=$NEW_TAG" >> $GITHUB_ENV
        fi
        if [[ "$image" =~ $addon_platform ]]; then
            echo "Platform Addon Image Found Set Env Var: PLATFORM_ADDON=$NEW_TAG"
            echo "PLATFORM_ADDON=$NEW_TAG" >> $GITHUB_ENV
        fi
        if [[ "$image" =~ $hub_regex ]]; then
            echo "Hub Image Image Found Set Env Var: HUB=$NEW_TAG"
            echo "HUB=$NEW_TAG" >> $GITHUB_ENV
        fi
    done

    # Cleanup
    rm -rf "$TEMP_DIR"

    echo ""
    echo "Download and load complete. Re-checking images..."
    exec "$0"
else
    echo "------------------------------------------------------------"
    echo "Status: All required images are present"
    exit 0
fi
