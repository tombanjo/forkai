#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name: 05-setup-google-ai-studio-api-key.sh
# Description: This script sets up Google AI Studio API key headlessly.
#              It enables the Generative Language API and creates an API key
#              that can be used with Google AI Studio.
#
# Usage:
#   ./05-setup-google-ai-studio-api-key.sh [PROJECT_ID] [KEY_NAME] [SECRET_NAME]
#
# Arguments:
#   PROJECT_ID (optional): The ID of the Google Cloud project. Defaults to
#                          "my-gcp-project" if not provided.
#   KEY_NAME (optional): Display name for the API key. Defaults to
#                        "gemini-api-key" if not provided.
#   SECRET_NAME (optional): Secret Manager secret name to store the key.
#                           Defaults to "${KEY_NAME}-secret" if not provided.
#
# Features:
#   - Enables the Generative Language API
#   - Creates an API key for Google AI Studio
#   - Outputs the API key (store securely!)
#   - Optionally restricts the key to Generative Language API only
#   - Stores the API key in Secret Manager
#
# Prerequisites:
#   - The user must have the Google Cloud SDK installed and authenticated.
#   - The user must have appropriate permissions to enable APIs and create API keys.
#
# Security Notes:
#   - API keys are less secure than service accounts
#   - Consider using Vertex AI with service accounts instead (already configured)
#   - Store the API key in Secret Manager or environment variables
#   - Restrict the key to only the Generative Language API
#
# Example:
#   ./05-setup-google-ai-studio-api-key.sh my-project-id my-gemini-key my-gemini-secret
# -----------------------------------------------------------------------------

# Input attributes with default values
PROJECT_ID=${1:-"my-gcp-project"}
KEY_NAME=${2:-"gemini-api-key"}
SECRET_NAME=${3:-"${KEY_NAME}-secret"}

echo "Setting up Google AI Studio API key for project: ${PROJECT_ID}"

# Verify project exists
if ! gcloud projects describe "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Error: Project ${PROJECT_ID} not found or you don't have access to it."
  exit 1
fi

# Enable required APIs
echo "Enabling Generative Language API and Secret Manager..."
gcloud services enable generativelanguage.googleapis.com secretmanager.googleapis.com \
  --project="${PROJECT_ID}"

# Wait a moment for API to be fully enabled
sleep 5

# Create the API key
echo "Creating API key: ${KEY_NAME}..."
gcloud services api-keys create \
  --display-name="${KEY_NAME}" \
  --project="${PROJECT_ID}"

# Look up the most recent key with this display name
KEY_RESOURCE=$(gcloud services api-keys list \
  --project="${PROJECT_ID}" \
  --filter="displayName=${KEY_NAME}" \
  --sort-by="~createTime" \
  --limit=1 \
  --format="value(name)")

if [ -z "$KEY_RESOURCE" ]; then
  echo "Error: Failed to locate the created API key"
  exit 1
fi

# Extract the key ID from the full resource name
# Format: projects/PROJECT_NUMBER/locations/global/keys/KEY_ID
KEY_ID=$(echo "$KEY_RESOURCE" | awk -F'/' '{print $NF}')

# Get the actual API key value
echo "Retrieving API key value..."
API_KEY_VALUE=$(gcloud services api-keys get-key-string "${KEY_ID}" \
  --project="${PROJECT_ID}" \
  --format="value(keyString)")

if [ -z "$API_KEY_VALUE" ]; then
  echo "Error: Failed to retrieve API key value"
  exit 1
fi

# Restrict the API key to only Generative Language API
echo "Restricting API key to Generative Language API only..."
gcloud services api-keys update "${KEY_ID}" \
  --api-target=service=generativelanguage.googleapis.com \
  --project="${PROJECT_ID}" \
  --quiet

echo ""
echo "=========================================="
echo "API Key created successfully!"
echo "=========================================="
echo "Key Name: ${KEY_NAME}"
echo "Key ID: ${KEY_ID}"
echo "API Key: ${API_KEY_VALUE}"
echo ""
echo "Storing API key in Secret Manager..."
if ! gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud secrets create "${SECRET_NAME}" \
    --replication-policy="automatic" \
    --project="${PROJECT_ID}"
fi

printf "%s" "${API_KEY_VALUE}" | gcloud secrets versions add "${SECRET_NAME}" \
  --data-file=- \
  --project="${PROJECT_ID}"

echo "Verifying secret value via gcloud..."
SECRET_VALUE=$(gcloud secrets versions access latest \
  --secret="${SECRET_NAME}" \
  --project="${PROJECT_ID}")

echo ""
echo "Secret created/updated successfully!"
echo "Secret Name: ${SECRET_NAME}"
echo "Secret Value (latest): ${SECRET_VALUE}"
echo ""
echo "⚠️  SECURITY WARNING:"
echo "   - Do NOT commit the API key to source control"
echo "   - Consider using Vertex AI with service accounts instead (more secure)"
echo ""
echo "To use this key, set the environment variable:"
echo "  export GOOGLE_AI_STUDIO_API_KEY=\"${API_KEY_VALUE}\""
echo ""
echo "Or add it to Cloud Run as a secret:"
echo "  gcloud run services update SERVICE_NAME \\"
echo "    --update-secrets=GOOGLE_AI_STUDIO_API_KEY=${SECRET_NAME}:latest \\"
echo "    --project=${PROJECT_ID} \\"
echo "    --region=REGION"
echo "=========================================="
