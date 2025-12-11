#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  sudo apt-get update -y && sudo apt-get install -y jq
fi

# Environment variables must be set by caller:
# - GIT_SHA: Git commit SHA
# - BUCKET: S3 bucket name for artifacts

if [ -z "$GIT_SHA" ] ; then
  echo "Error: Required environment variables not set (GIT_SHA)"
  exit 1
fi

if [ -z "$BUCKET" ] ; then
  echo "Error: Required environment variables not set (BUCKET)"
  exit 1
fi

PREFIX="artifacts/${GIT_SHA}"   # this costructs the path in s3 
ZIP="./terraform/lambda-deployment.zip"
HASH_B64="$(openssl dgst -sha256 -binary "$ZIP" | base64)"
for FUNC in getReport updateMetricsDatabase processSqsMessage; do

  echo "${FUNC}"

  # Create zip file from the directory
  echo "Creating zip file for ${FUNC}..."

  S3_KEY="${PREFIX}/${FUNC}.zip"

  aws s3 cp "$ZIP" "s3://${BUCKET}/${S3_KEY}" \
    --metadata "git-sha=${GIT_SHA},function-name=${FUNC},sha256_b64=${HASH_B64}"
  echo "Artifact uploaded: s3://${BUCKET}/${S3_KEY}"

  echo "${FUNC}_s3_key=${S3_KEY}"
  echo "${FUNC}_source_code_hash=${HASH_B64}"

  # Outputs we can use later in terraform steps (will pass this as input to tf)
  {
    echo "${FUNC}_s3_key=${S3_KEY}"
    echo "${FUNC}_source_code_hash=${HASH_B64}"
  } >> "$GITHUB_OUTPUT"
done

{
  echo "artifact_bucket=${BUCKET}"
  echo "git_sha=${GIT_SHA}"
} >> "$GITHUB_OUTPUT"
