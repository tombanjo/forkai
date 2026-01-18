#!/bin/bash

# Get project ID from first argument or use default
PROJECT_ID=${1:-"my-gcp-project"}
# Bucket name follows the pattern: {PROJECT_ID}-spa
BUCKET_NAME="${PROJECT_ID}-spa"

WORKING_DIR="application/test-application"

cd $WORKING_DIR || { echo "Directory $WORKING_DIR not found."; exit 1; }

echo "Uploading to bucket: ${BUCKET_NAME}"
bash upload-to-cloud-storage.sh "$BUCKET_NAME"