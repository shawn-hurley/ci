#!/bin/bash

set -e

REQUIRED_IMAGES=(
    "quay.io/konveyor/tackle2-hub"
    "quay.io/konveyor/tackle2-addon-analyzer"
    "quay.io/konveyor/tackle2-addon-discovery"
    "quay.io/konveyor/tackle2-addon-platform"
    "quay.io/konveyor/tackle-keycloak-init"
    "quay.io/konveyor/c-sharp-provider"
    "quay.io/konveyor/java-external-provider"
    "quay.io/konveyor/generic-external-provider"
)

echo "Checking for required podman images..."
echo "------------------------------------------------------------"

# Get list of all podman images
IMAGES=$(podman images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)

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
    WORKFLOW_RUN=$(gh run list --workflow=nightly-koncur.yaml --status=success --limit=1 --json databaseId --jq '.[0].databaseId')

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
        if gh run download "$WORKFLOW_RUN" --pattern "${ARTIFACT_PREFIX}--*" --dir "$TEMP_DIR" 2>/dev/null; then
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
        LOADED_IMAGE=$(podman load -i "${image}" | awk '{print $3}')
        echo "Loaded image: $LOADED_IMAGE"

        # Re-tag if we have a tag from found images
        if [ -n "$FOUND_TAG" ] && [ -n "$LOADED_IMAGE" ]; then
            # Extract the repository name (without the tag)
            IMAGE_REPO=$(echo "$LOADED_IMAGE" | cut -d':' -f1)
            NEW_TAG="${IMAGE_REPO}:${FOUND_TAG}"
            echo "Re-tagging to: $NEW_TAG"
            podman tag "$LOADED_IMAGE" "$NEW_TAG"
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
