#!/bin/bash

export TF_VAR_project_id=${1:-"my-gcp-project"}
export TF_VAR_region=${2:-"us-central1"}
# Default bucket name includes project ID to ensure uniqueness (GCS bucket names must be globally unique)
if [ -z "$3" ]; then
  export TF_VAR_spa_bucket_name="${TF_VAR_project_id}-spa"
else
  export TF_VAR_spa_bucket_name="$3"
fi
export TF_VAR_service_name=${4:-"chat-service"}

# Verify project exists and authentication
echo "Verifying project: ${TF_VAR_project_id}"
echo "Using SPA bucket name: ${TF_VAR_spa_bucket_name}"
if ! gcloud projects describe "${TF_VAR_project_id}" >/dev/null 2>&1; then
  echo "Error: Project ${TF_VAR_project_id} not found or you don't have access to it."
  exit 1
fi

# Verify authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  echo "Error: No active authentication found. Please run: gcloud auth login"
  exit 1
fi

# Set up application default credentials if not already set
gcloud auth application-default print-access-token >/dev/null 2>&1 || gcloud auth application-default login

WORKING_DIR="terraform/stages/repositories"

# Change to the desired working directory
cd $WORKING_DIR || { echo "Directory $WORKING_DIR not found."; exit 1; }

# Create backend configuration file with the correct bucket name
BACKEND_BUCKET="terraform-remote-state-${TF_VAR_project_id}"
echo "Using backend bucket: ${BACKEND_BUCKET}"

# Check if bucket exists
if ! gsutil ls -b "gs://${BACKEND_BUCKET}" >/dev/null 2>&1; then
  echo "Warning: Backend bucket ${BACKEND_BUCKET} does not exist."
  echo "Please run ./scripts/00-init-project.sh ${TF_VAR_project_id} first to create it."
  exit 1
fi

# Create backend configuration file
cat > backend.tfbackend <<EOF
bucket = "${BACKEND_BUCKET}"
prefix = "dev/terraform/state/repositories"
EOF
echo "Created backend configuration file: backend.tfbackend"

# Run Terraform commands
echo "Initializing Terraform..."
terraform init -input=false -reconfigure -backend-config=backend.tfbackend || {
  echo "Error: Terraform initialization failed."
  exit 1
}

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

echo "Development infrastructure deployment complete!"