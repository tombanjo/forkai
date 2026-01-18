#!/bin/bash

# Set variables
BUCKET_NAME=${1:-my-web-app}

# Check if bucket exists
echo "Checking if bucket $BUCKET_NAME exists..."
if ! gcloud storage buckets describe "gs://$BUCKET_NAME" >/dev/null 2>&1; then
  echo "Error: Bucket gs://$BUCKET_NAME does not exist."
  echo "Please run ./scripts/02-dev-infrastructure.sh <PROJECT_ID> first to create the bucket."
  exit 1
fi

# Upload all files recursively with no-cache headers
echo "Uploading current directory to bucket $BUCKET_NAME with cache-control headers..."

find . -type f | while read -r file; do
  if [[ "$file" != "." ]]; then
    # Remove leading ./ from file path
    file_path="${file#./}"
    # Skip the upload script itself
    if [[ "$file_path" == "upload-to-cloud-storage.sh" ]]; then
      continue
    fi
    echo "Uploading: $file_path"
    gcloud storage cp "$file" "gs://$BUCKET_NAME/$file_path" \
      --cache-control="public, max-age=0" || { echo "Failed to upload $file"; exit 1; }
  fi
done

echo "Upload completed successfully."
