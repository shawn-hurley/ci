#!/bin/bash

FILE_PATH=$1
CLUSTER_NAME=${2:-koncur-test}

hub_regex=".*tackle2-hub.*"
addon_regex=".*tackle2-addon-analyzer.*"
addon_discovery=".*tackle2-addon-discovery.*"
addon_platform=".*tackle2-addon-platform.*"
keycloak_init=".*tackle-keycloak-init.*"
java_provider_image_regex=".*java(-external)?-provider.*"
c_sharp_provider_image_regex=".*c-sharp-provider.*"
generic_provider_image_regex=".*generic(-external)?-provider.*"

for image in $(find "$FILE_PATH" -type f -name "*.tar"); do
    echo "Attempting to load image: ${image}"
    
    # Extract image name from tar file metadata before loading
    result=$(tar -xOf "${image}" manifest.json 2>/dev/null | jq -r '.[0].RepoTags[0] // empty' 2>/dev/null)
    
    if [ -z "$result" ]; then
        echo "Warning: Could not extract image name from ${image}, skipping..."
        continue
    fi
    
    echo "Image name: $result"
    
    # Load the image into Kind cluster
    kind load image-archive "${image}" --name "${CLUSTER_NAME}"
    
    if [[ "$image" =~ $java_provider_image_regex ]]; then
        echo "Java Provider Image Found Set Env Var: JAVA_PROVIDER_IMG=$result"
        echo "JAVA_PROVIDER_IMG=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $c_sharp_provider_image_regex ]]; then
        echo "C Sharp Provider Found Set Env Var: CSHARP_PROVIDER_IMG=$result"
        echo "CSHARP_PROVIDER_IMG=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $generic_provider_image_regex ]]; then
        echo "Generic Provider Image Found Set Env Var: GENERIC_PROVIDER_IMG=$result"
        echo "GENERIC_PROVIDER_IMG=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $addon_regex ]]; then
        echo "Addon-Analyzer Image Found Set Env Var: ANALYZER_ADDON=$result"
        echo "ANALYZER_ADDON=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $addon_discovery ]]; then
        echo "Discovery Addon Image Found Set Env Var: DISCOVERY_ADDON=$result"
        echo "DISCOVERY_ADDON=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $addon_platform ]]; then
        echo "Platform Addon Image Found Set Env Var: PLATFORM_ADDON=$result"
        echo "PLATFORM_ADDON=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $hub_regex ]]; then
        echo "Hub Image Found Set Env Var: HUB=$result"
        echo "HUB=$result" >> $GITHUB_ENV
    fi

done
