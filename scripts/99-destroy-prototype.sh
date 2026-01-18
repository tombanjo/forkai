#!/bin/bash

export TF_VAR_project_id=${1:-"my-gcp-project"}
export TF_VAR_region=${2:-"us-central1"}
# Default bucket name matches script 02 (GCS bucket names must be globally unique)
if [ -z "$3" ]; then
  export TF_VAR_spa_bucket_name="${TF_VAR_project_id}-spa"
else
  export TF_VAR_spa_bucket_name="$3"
fi
export TF_VAR_service_name=${4:-"chat-service"}

# Verify project exists
echo "Verifying project: ${TF_VAR_project_id}"
if ! gcloud projects describe "${TF_VAR_project_id}" >/dev/null 2>&1; then
  echo "Error: Project ${TF_VAR_project_id} not found or you don't have access to it."
  exit 1
fi

WORKING_DIR="terraform/stages/prototype"

# Change to the desired working directory
cd $WORKING_DIR || { echo "Directory $WORKING_DIR not found."; exit 1; }

# Create backend configuration file with the correct bucket name
BACKEND_BUCKET="terraform-remote-state-${TF_VAR_project_id}"
echo "Using backend bucket: ${BACKEND_BUCKET}"

# Create backend configuration file
cat > backend.tfbackend <<EOF
bucket = "${BACKEND_BUCKET}"
prefix = "dev/terraform/state/prototype"
EOF

# Initialize Terraform with backend config
echo "Initializing Terraform..."
terraform init -input=false -reconfigure -backend-config=backend.tfbackend || {
  echo "Error: Terraform initialization failed."
  exit 1
}

# Run Terraform destroy
echo "Destroying infrastructure..."
terraform destroy -input=false -auto-approve || {
  echo "Error: Terraform destroy failed."
  exit 1
}

echo "Infrastructure destruction complete!"