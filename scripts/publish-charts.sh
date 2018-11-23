#!/bin/bash

set -e

# Get the first semver tag
IFS=',' read -ra TAGS <<< $(cat .tags)
for t in "${TAGS[@]}"; do
    echo "Found tag: ${t}"
    if [[ $t =~ [v]*[0-9]+\.[0-9]+\.[0-9]+.* ]]; then
        VERSION=$t
        break
    fi
done
echo "VERSION: $VERSION"

# If master then its a "release", else its a feature branch.
# Releases are named with the git repo name
if [ "${CICD_GIT_BRANCH}" == "master" ]; then
    echo "Found master branch."
    CHART_NAME="${CICD_GIT_REPO_NAME}"
else
    echo "Found feature branch."
    CHART_NAME="${CICD_GIT_BRANCH}"
fi
echo "CHART_NAME: ${CHART_NAME}"

mkdir -p .build/charts
cp -R ./.chart/${CICD_GIT_REPO_NAME} .build/${CHART_NAME}

# sed replace version and name
sed -i -e "s/%VERSION%/${VERSION}/g" .build/${CHART_NAME}/Chart.yaml
sed -i -e "s/%CHART_NAME%/${CHART_NAME}/g" .build/${CHART_NAME}/Chart.yaml

# Init Helm
helm init -c

# Lint Chart
helm lint .build/${CHART_NAME}

# Package Chart
helm package -d .build/charts .build/${CHART_NAME}

# Add Remote Repo
helm repo add --username "${HELM_REPO_USERNAME}" --password "${HELM_REPO_PASSWORD}" \
${CICD_GIT_REPO_NAME} https://vote-demo-charts.eng.rancher.space/${CICD_GIT_REPO_NAME}/

# Publish Chart 
helm push .build/charts/${CHART_NAME}-${VERSION}.tgz ${CICD_GIT_REPO_NAME}