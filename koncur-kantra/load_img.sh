FILE_PATH=$1
kantra_image_regex=".*kantra.*"
java_provider_image_regex=".*java(-external)?-provider.*"
c_sharp_provider_image_regex=".*c-sharp-provider.*"
generic_provider_image_regex=".*generic(-external)?-provider.*"
for image in $(find "$FILE_PATH" -type f -name "*.tar"); do
    echo "Attempting to load image: ${image}"

    if [[ "$image" =~ $kantra_image_regex ]]; then
        result=$(podman load -i "${image}" | awk '{print $3}')
        echo "Kantra Image Found Set Env Var: RUNNER_IMG=$result"
        echo "RUNNER_IMG=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $java_provider_image_regex ]]; then
        result=$(podman load -i "${image}" | awk '{print $3}')
        echo "Java Provider Image Found Set Env Var: JAVA_PROVIDER_IMG=$result"
        echo "JAVA_PROVIDER_IMG=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $c_sharp_provider_image_regex ]]; then
        result=$(podman load -i "${image}" | awk '{print $3}')
        echo "C Sharp Provider Found Set Env Var: CSHARP_PROVIDER_IMG=$result"
        echo "CSHARP_PROVIDER_IMG=$result" >> $GITHUB_ENV
    fi
    if [[ "$image" =~ $generic_provider_image_regex ]]; then
        result=$(podman load -i "${image}" | awk '{print $3}')
        echo "Generic Provider Image Found Set Env Var: GENERIC_PROVIDER_IMG=$result"
        echo "GENERIC_PROVIDER_IMG=$result" >> $GITHUB_ENV
    fi

done
