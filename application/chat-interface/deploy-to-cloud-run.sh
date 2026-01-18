#!/bin/bash

# Variables
PROJECT_ID=${1:-"my-gcp-project"}
REGION=${2:-"us-central1"}
SERVICE_NAME=${3:-"chat-service"}
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}"

echo "Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_NAME" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --quiet

if [ $? -ne 0 ]; then
    echo "Failed to build or publish the container image."
    exit 1
fi

echo "Successfully built and published image: $IMAGE_NAME"