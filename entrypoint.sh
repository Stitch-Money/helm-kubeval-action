#!/bin/sh -l

# Exit on error.
set -e;

CURRENT_DIR=$(pwd);

run_kubeval() {
    # Validate all generated manifest against Kubernetes json schema
    cd "$1"
    VALUES_FILE="$2"
    mkdir -p helm-output;
    helm template --values "$VALUES_FILE" --output-dir helm-output .;
    find helm-output -type f -exec \
        kubeval \
            "-o=$OUTPUT" \
            "--strict=$STRICT" \
            "--kubernetes-version=$KUBERNETES_VERSION" \
            "--openshift=$OPENSHIFT" \
            "--ignore-missing-schemas=$IGNORE_MISSING_SCHEMAS" \
            "--schema-location=https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master" \
        {} +;
    rm -rf helm-output;
}

# Parse helm repos located in the $CONFIG_FILE file / Ignore commented lines (#)
while read REPO_CONFIG
do
    case "$REPO_CONFIG" in \#*) continue ;; esac
    REPO=$(echo $REPO_CONFIG | cut -d '=' -f1);
    URL=$(echo $REPO_CONFIG | cut -d '=' -f2);
    helm repo add $REPO $URL;
done < "$CONFIG_FILE"

helm repo update

# For all charts (i.e for every directory) in the directory
for CHART in "$CHARTS_PATH"/*/; do
    echo "Chart is $CHART"
    echo "Validating $CHART Helm Chart...";
    cd "$CHART";
    helm dependency build --skip-refresh;

    for VALUES_FILE in *-values.yaml; do
        echo "Validating $CHART Helm Chart using $VALUES_FILE values file...";
        run_kubeval "$(pwd)" "$VALUES_FILE"
    done
    run_kubeval "$(pwd)" "values.yaml"
    echo "Cleanup $(pwd)/charts directory after we are done running Kubeval"
    rm -rf $(pwd)/charts/
done
