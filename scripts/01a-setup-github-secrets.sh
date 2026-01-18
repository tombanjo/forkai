#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name: 01a-setup-github-secrets.sh
# Description: Pushes required secrets to GitHub repository for CI/CD workflows.
#              Must be run after 01-deploy-github-provider.sh.
#
# Usage: ./01a-setup-github-secrets.sh [PROJECT_ID]
#
# Arguments:
#   PROJECT_ID  (Optional) The Google Cloud project ID. Defaults to "my-gcp-project".
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Git repository with GitHub remote configured
#   - Terraform github-provider stage already deployed (01-deploy-github-provider.sh)
#
# Secrets Created:
#   - PROJECT_ID
#   - PROJECT_NUMBER
#   - SERVICE_ACCOUNT_EMAIL
#   - WORKLOAD_IDENTITY_POOL_ID
#   - WORKLOAD_IDENTITY_POOL_PROVIDER_ID
#
# Exit Codes:
#   0 - Success
#   1 - Failure
# -----------------------------------------------------------------------------

set -e

PROJECT_ID=${1:-"my-gcp-ai-project"}

echo "=== GitHub Secrets Setup ==="
echo "Project ID: ${PROJECT_ID}"
echo ""

# -----------------------------------------------------------------------------
# Validate GitHub CLI authentication
# -----------------------------------------------------------------------------
echo "Validating GitHub CLI authentication..."
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI is not authenticated."
  echo "Please run: gh auth login"
  exit 1
fi
echo "GitHub CLI authenticated."

# -----------------------------------------------------------------------------
# Validate we're in a git repo with GitHub remote
# -----------------------------------------------------------------------------
echo "Validating git repository..."
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Error: No git remote 'origin' found."
  echo "Please ensure this is a git repository with a GitHub remote."
  exit 1
fi

REPO_URL=$(git remote get-url origin)
echo "Repository: ${REPO_URL}"

# -----------------------------------------------------------------------------
# Get PROJECT_NUMBER from GCP
# -----------------------------------------------------------------------------
echo ""
echo "Fetching PROJECT_NUMBER from GCP..."
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
if [ -z "${PROJECT_NUMBER}" ]; then
  echo "Error: Could not fetch project number for ${PROJECT_ID}"
  exit 1
fi
echo "PROJECT_NUMBER: ${PROJECT_NUMBER}"

# -----------------------------------------------------------------------------
# Get Terraform outputs from github-provider stage
# -----------------------------------------------------------------------------
echo ""
echo "Fetching Terraform outputs from github-provider stage..."

TERRAFORM_DIR="terraform/stages/github-provider"
if [ ! -d "${TERRAFORM_DIR}" ]; then
  echo "Error: Terraform directory not found: ${TERRAFORM_DIR}"
  exit 1
fi

cd "${TERRAFORM_DIR}"

# Check if terraform state exists
if ! terraform output >/dev/null 2>&1; then
  echo "Error: Cannot read Terraform outputs."
  echo "Please run 01-deploy-github-provider.sh first."
  exit 1
fi

SERVICE_ACCOUNT_EMAIL=$(terraform output -raw service_account_email)
WORKLOAD_IDENTITY_POOL_ID=$(terraform output -raw workload_identity_pool_id)
WORKLOAD_IDENTITY_POOL_PROVIDER_ID=$(terraform output -raw workload_identity_pool_provider_id)

cd - >/dev/null

echo "SERVICE_ACCOUNT_EMAIL: ${SERVICE_ACCOUNT_EMAIL}"
echo "WORKLOAD_IDENTITY_POOL_ID: ${WORKLOAD_IDENTITY_POOL_ID}"
echo "WORKLOAD_IDENTITY_POOL_PROVIDER_ID: ${WORKLOAD_IDENTITY_POOL_PROVIDER_ID}"

# -----------------------------------------------------------------------------
# Push secrets to GitHub
# -----------------------------------------------------------------------------
echo ""
echo "Pushing secrets to GitHub repository..."

gh secret set PROJECT_ID --body "${PROJECT_ID}"
echo "  PROJECT_ID"

gh secret set PROJECT_NUMBER --body "${PROJECT_NUMBER}"
echo "  PROJECT_NUMBER"

gh secret set SERVICE_ACCOUNT_EMAIL --body "${SERVICE_ACCOUNT_EMAIL}"
echo "  SERVICE_ACCOUNT_EMAIL"

gh secret set WORKLOAD_IDENTITY_POOL_ID --body "${WORKLOAD_IDENTITY_POOL_ID}"
echo "  WORKLOAD_IDENTITY_POOL_ID"

gh secret set WORKLOAD_IDENTITY_POOL_PROVIDER_ID --body "${WORKLOAD_IDENTITY_POOL_PROVIDER_ID}"
echo "  WORKLOAD_IDENTITY_POOL_PROVIDER_ID"

echo ""
echo "=== GitHub secrets setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Create GitHub environment 'rapid-prototype' in repo settings"
echo "  2. Run: ./scripts/02-dev-infrastructure.sh ${PROJECT_ID}"
