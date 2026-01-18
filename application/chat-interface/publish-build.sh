#!/bin/bash

# Variables
PROJECT_ID=${1:-"my-gcp-project"}
REGION=${2:-"us-central1"}
SERVICE_NAME=${3:-"chat-service"}
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}"

# Check if pack command is available
if ! command -v pack &> /dev/null; then
    echo "Error: 'pack' command not found."
    echo "Please install Cloud Native Buildpacks CLI:"
    echo "  Visit: https://buildpacks.io/docs/tools/pack/"
    exit 1
fi

# Check if Docker is available and accessible
if ! command -v docker &> /dev/null; then
    echo "Error: 'docker' command not found."
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker daemon access
if ! docker info &> /dev/null; then
    echo "Error: Cannot access Docker daemon."
    
    # Check if Docker is installed via snap
    if command -v snap &> /dev/null && snap list docker &> /dev/null 2>&1; then
        echo "Docker is installed via snap."
        echo ""
        echo "For snap-installed Docker, create the docker group and add your user:"
        echo "  1. Create the docker group: sudo groupadd docker"
        echo "  2. Add your user to the group: sudo usermod -aG docker $USER"
        echo "  3. Apply changes: newgrp docker"
        echo ""
        echo "Alternatively, you can temporarily fix socket permissions:"
        echo "  sudo chmod 666 /var/run/docker.sock"
    else
        echo "This usually means:"
        echo "  1. Docker daemon is not running (try: sudo systemctl start docker)"
        echo "  2. Your user doesn't have permission to access Docker"
        echo ""
        echo "To fix permission issues, add your user to the docker group:"
        echo "  sudo usermod -aG docker $USER"
        echo "  Then log out and log back in, or run: newgrp docker"
    fi
    exit 1
fi

# Verify gcloud authentication
echo "Verifying gcloud authentication..."
# Check if we can get an access token (works with both user auth and workload identity)
if ! gcloud auth print-access-token >/dev/null 2>&1; then
    echo "Error: Cannot get access token. Authentication may have failed."
    echo "Please verify authentication: gcloud auth list"
    exit 1
fi
# Set the project if not already set
gcloud config set project "${PROJECT_ID}" --quiet 2>/dev/null || true
echo "Authentication verified. Using project: ${PROJECT_ID}"

# Configure Docker to authenticate with Artifact Registry
echo "Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Also authenticate using access token method (more reliable for pushing)
echo "Authenticating Docker with access token..."
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "${REGION}-docker.pkg.dev" || {
    echo "Error: Failed to authenticate Docker with Artifact Registry."
    exit 1
}

# Optional: Generate package-lock.json if npm is available and lock file is missing
# This ensures reproducible builds and faster buildpack execution
if command -v npm &> /dev/null; then
    if [ ! -f "package-lock.json" ]; then
        echo "Generating package-lock.json for reproducible builds..."
        npm install --package-lock-only --no-save || {
            echo "Warning: Failed to generate package-lock.json. Buildpacks will generate it during build."
        }
    else
        echo "Verifying package-lock.json is in sync with package.json..."
        npm ci --dry-run >/dev/null 2>&1 || {
            echo "Warning: package-lock.json is out of sync. Regenerating..."
            npm install --package-lock-only --no-save || {
                echo "Warning: Failed to regenerate package-lock.json. Buildpacks will handle it."
            }
        }
    fi
else
    echo "Note: npm not found locally. Buildpacks will handle dependency installation."
fi

# Step 1: Build the container image using the Cloud Native Buildpacks
echo "Building the container image using buildpacks..."
# Build locally first (without --publish) to ensure we can tag it properly
pack build "${IMAGE_NAME}:latest" \
  --builder gcr.io/buildpacks/builder:google-22 \
  --trust-builder \
  --path .

if [ $? -ne 0 ]; then
    echo "Failed to build the container image."
    exit 1
fi

# Step 2: Ensure authentication is still valid and push the image to Artifact Registry
echo "Pushing image to Artifact Registry..."
# Re-authenticate right before push to ensure token is fresh
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "${REGION}-docker.pkg.dev" >/dev/null 2>&1
docker push "${IMAGE_NAME}:latest"

if [ $? -ne 0 ]; then
    echo "Failed to push the container image."
    exit 1
fi

echo "Successfully built and published image: ${IMAGE_NAME}:latest"