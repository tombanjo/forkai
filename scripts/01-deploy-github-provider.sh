#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name: 01-deploy-github-provider.sh
# Description: This script automates the deployment of a GitHub provider 
#              configuration using Terraform. It initializes Terraform, 
#              generates a plan, and applies the configuration.
#
# Usage: ./01-deploy-github-provider.sh [PROJECT_ID] [GITHUB_REPOSITORY]
#
# Arguments:
#   PROJECT_ID        (Optional) The Google Cloud project ID. Defaults to "my-gcp-project".
#   GITHUB_REPOSITORY (Optional) The GitHub repository in the format "owner/repo". 
#                     Defaults to "tombanjo/ai-web-component".
#
# Prerequisites:
#   - Ensure Terraform is installed and available in the system PATH.
#   - The script must be executed from a directory containing the Terraform 
#     configuration files under "terraform/stages/github-provider".
#
# Behavior:
#   1. Navigates to the Terraform configuration directory.
#   2. Initializes Terraform with the `terraform init` command.
#   3. Creates a Terraform execution plan using `terraform plan`.
#   4. Applies the Terraform configuration using `terraform apply`.
#
# Exit Codes:
#   0 - Success
#   1 - Failure (e.g., directory not found, Terraform errors).
#
# Example:
#   ./01-deploy-github-provider.sh my-project myuser/myrepo
# -----------------------------------------------------------------------------
export TF_VAR_project_id=${1:-"my-gcp-project"}
export TF_VAR_github_repository=${2:-"tombanjo/ai-web-component"}

# Verify project exists and authentication
echo "Verifying project: ${TF_VAR_project_id}"
if ! gcloud projects describe "${TF_VAR_project_id}" >/dev/null 2>&1; then
  echo "Error: Project ${TF_VAR_project_id} not found or you don't have access to it."
  echo "Please ensure you are authenticated: gcloud auth login"
  exit 1
fi

# Verify authentication
echo "Verifying authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  echo "Error: No active authentication found."
  echo "Please run: gcloud auth login"
  exit 1
fi

# Set up application default credentials if not already set
echo "Setting up application default credentials..."
gcloud auth application-default print-access-token >/dev/null 2>&1 || gcloud auth application-default login

# Change to the desired working directory
cd terraform/stages/github-provider || { echo "Directory 'terraform/stages/github-provider' not found."; exit 1; }

# Create backend configuration file with the correct bucket name
BACKEND_BUCKET="terraform-remote-state-${TF_VAR_project_id}"
echo "Using backend bucket: ${BACKEND_BUCKET}"

# Check if bucket exists
if ! gsutil ls -b "gs://${BACKEND_BUCKET}" >/dev/null 2>&1; then
  echo "Warning: Backend bucket ${BACKEND_BUCKET} does not exist."
  echo "Please run ./scripts/00-init-project.sh ${TF_VAR_project_id} first to create it."
  exit 1
fi

# Create backend configuration file (overwrite if exists)
cat > backend.tfbackend <<EOF
bucket = "${BACKEND_BUCKET}"
prefix = "dev/terraform/state/github-provider"
EOF
echo "Created backend configuration file: backend.tfbackend"

# Update terraform.tfvars with current project and repository (if it exists, backup and update)
if [ -f terraform.tfvars ]; then
  echo "Updating terraform.tfvars with current project and repository..."
  cp terraform.tfvars terraform.tfvars.backup 2>/dev/null || true
fi
cat > terraform.tfvars <<EOF
project_id = "${TF_VAR_project_id}"
github_repository = "${TF_VAR_github_repository}"
EOF
echo "Updated terraform.tfvars with project_id=${TF_VAR_project_id} and github_repository=${TF_VAR_github_repository}"

# Initialize Terraform first (required before any other operations)
echo "Initializing Terraform with backend configuration..."
terraform init -input=false -reconfigure -backend-config=backend.tfbackend || {
  echo "Error: Terraform initialization failed."
  exit 1
}

# Try to import existing resources (after init, so state backend is available)
# Use the same pool ID as the Terraform default
POOL_ID=${TF_VAR_workload_identity_pool_id:-"github-actions-pool-ai-startup"}
PROVIDER_ID=${TF_VAR_workload_identity_pool_provider_id:-"github-actions-provider"}

echo "Attempting to import existing resources (if any)..."
terraform import google_iam_workload_identity_pool.github_pool \
    "projects/${TF_VAR_project_id}/locations/global/workloadIdentityPools/${POOL_ID}" 2>/dev/null || \
    echo "Workload Identity Pool does not exist yet. It will be created."

terraform import google_iam_workload_identity_pool_provider.github_provider \
    "projects/${TF_VAR_project_id}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}" 2>/dev/null || \
    echo "Workload Identity Pool Provider does not exist yet. It will be created."

# Check if the Service Account exists
if gcloud iam service-accounts describe "github-actions@${TF_VAR_project_id}.iam.gserviceaccount.com" \
  --project="${TF_VAR_project_id}" >/dev/null 2>&1; then
  echo "Service Account exists. Importing into Terraform state..."
  terraform import google_service_account.github_actions \
    "projects/${TF_VAR_project_id}/serviceAccounts/github-actions@${TF_VAR_project_id}.iam.gserviceaccount.com" 2>/dev/null || \
    echo "Note: Service Account exists but import may have failed. Terraform will handle this."
else
  echo "Service Account does not exist. It will be created by Terraform."
fi

# Run Terraform plan and apply
echo "Creating Terraform plan..."
terraform plan -out=tfplan -input=false || {
  echo "Error: Terraform plan failed."
  exit 1
}

echo "Applying Terraform configuration..."
terraform apply -input=false -auto-approve tfplan || {
  echo "Error: Terraform apply failed."
  exit 1
}

echo "GitHub provider deployment complete!"