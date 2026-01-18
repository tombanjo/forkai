#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name: setup.sh
# Description: One-command setup for the entire AI Web Component infrastructure.
#              Runs all setup scripts (00-07) in sequence to bootstrap a fully
#              working deployment.
#
# Usage:
#   ./setup.sh [PROJECT_ID] [REGION]
#
# Arguments:
#   PROJECT_ID (optional): GCP project ID. If not provided, derived from:
#                          1. Git repository name (preferred)
#                          2. Current directory name (fallback)
#   REGION (optional): GCP region. Defaults to "us-central1"
#
# Prerequisites:
#   - Bash shell
#   - Git with GitHub remote configured
#   - GitHub CLI (gh) authenticated
#   - Google Cloud SDK (gcloud) authenticated
#   - Terraform installed
#   - Node.js 18+ installed
#   - Pack CLI installed (for buildpacks)
#   - Docker installed and running
#
# What it does:
#   1. Validates all prerequisites and authentication
#   2. Derives project ID and GitHub repository from git remote
#   3. Runs infrastructure setup scripts in order:
#      - 00-init-project.sh (Terraform state bucket, enable APIs)
#      - 01-deploy-github-provider.sh (Workload Identity Federation)
#      - 01a-setup-github-secrets.sh (Push secrets to GitHub)
#      - 02-dev-infrastructure.sh (Artifact Registry, GCS bucket)
#      - 04-app-infrastructure.sh (Cloud Run service)
#      - 05-setup-google-ai-studio-api-key.sh (API key + Secret Manager)
#   4. Builds and deploys the application:
#      - Publish API to Artifact Registry
#      - Deploy API to Cloud Run
#      - Upload SPA to Cloud Storage
#
# Example:
#   ./setup.sh                          # Auto-derive from git repo
#   ./setup.sh my-project               # Explicit project ID
#   ./setup.sh my-project us-west1      # Explicit project ID and region
# -----------------------------------------------------------------------------

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
  echo ""
  echo -e "${BLUE}===================================================================${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}===================================================================${NC}"
  echo ""
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

# -----------------------------------------------------------------------------
# Derive PROJECT_ID from git repository name or directory name
# -----------------------------------------------------------------------------
derive_project_id() {
  local project_id=""
  
  # Try to get from git remote (preferred)
  if git remote get-url origin >/dev/null 2>&1; then
    local remote_url
    remote_url=$(git remote get-url origin)
    
    # Extract repo name from various URL formats:
    # - https://github.com/owner/repo.git
    # - git@github.com:owner/repo.git
    # - https://github.com/owner/repo
    project_id=$(echo "$remote_url" | sed -E 's/.*[\/:]([^\/]+)\.git$/\1/' | sed -E 's/.*[\/:]([^\/]+)$/\1/')
    
    if [ -n "$project_id" ]; then
      echo "$project_id"
      return 0
    fi
  fi
  
  # Fallback to directory name
  project_id=$(basename "$(pwd)")
  echo "$project_id"
}

# -----------------------------------------------------------------------------
# Get GitHub repository in owner/repo format
# -----------------------------------------------------------------------------
get_github_repo() {
  if ! git remote get-url origin >/dev/null 2>&1; then
    print_error "No git remote 'origin' found"
    return 1
  fi
  
  local remote_url
  remote_url=$(git remote get-url origin)
  
  # Extract owner/repo from various URL formats
  local github_repo
  github_repo=$(echo "$remote_url" | sed -E 's/.*github\.com[\/:]([^\/]+\/[^\/]+?)(\.git)?$/\1/')
  
  # Remove trailing .git if present
  github_repo="${github_repo%.git}"
  
  echo "$github_repo"
}

# -----------------------------------------------------------------------------
# Validate prerequisites
# -----------------------------------------------------------------------------
validate_prerequisites() {
  print_step "Validating Prerequisites"
  
  local has_errors=false
  
  # Check bash
  if [ -n "$BASH_VERSION" ]; then
    print_success "Bash: $BASH_VERSION"
  else
    print_error "Bash not detected"
    has_errors=true
  fi
  
  # Check git
  if command -v git &>/dev/null; then
    print_success "Git: $(git --version | head -1)"
  else
    print_error "Git not installed"
    has_errors=true
  fi
  
  # Check GitHub CLI
  if command -v gh &>/dev/null; then
    print_success "GitHub CLI: $(gh --version | head -1)"
  else
    print_error "GitHub CLI (gh) not installed. Install from: https://cli.github.com/"
    has_errors=true
  fi
  
  # Check Node.js
  if command -v node &>/dev/null; then
    print_success "Node.js: $(node --version)"
  else
    print_error "Node.js not installed. Install from: https://nodejs.org/"
    has_errors=true
  fi
  
  # Check gcloud
  if command -v gcloud &>/dev/null; then
    print_success "Google Cloud SDK: $(gcloud --version 2>/dev/null | head -1)"
  else
    print_error "Google Cloud SDK not installed. Install from: https://cloud.google.com/sdk/docs/install"
    has_errors=true
  fi
  
  # Check Terraform
  if command -v terraform &>/dev/null; then
    print_success "Terraform: $(terraform --version | head -1)"
  else
    print_error "Terraform not installed. Install from: https://www.terraform.io/downloads"
    has_errors=true
  fi
  
  # Check pack CLI
  if command -v pack &>/dev/null; then
    print_success "Pack CLI: $(pack --version)"
  else
    print_error "Pack CLI not installed. Install from: https://buildpacks.io/docs/tools/pack/"
    has_errors=true
  fi
  
  # Check Docker
  if command -v docker &>/dev/null; then
    if docker info &>/dev/null; then
      print_success "Docker: $(docker --version)"
    else
      print_error "Docker installed but daemon not accessible. Start Docker or check permissions."
      has_errors=true
    fi
  else
    print_error "Docker not installed. Install from: https://docs.docker.com/get-docker/"
    has_errors=true
  fi
  
  if [ "$has_errors" = true ]; then
    echo ""
    print_error "Please install missing prerequisites and try again."
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Validate authentication
# -----------------------------------------------------------------------------
validate_authentication() {
  print_step "Validating Authentication"
  
  local has_errors=false
  
  # Check GCP authentication
  if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    local gcp_account
    gcp_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
    print_success "GCP authenticated as: $gcp_account"
  else
    print_error "GCP not authenticated. Run: gcloud auth login"
    has_errors=true
  fi
  
  # Check GCP ADC
  if gcloud auth application-default print-access-token &>/dev/null; then
    print_success "GCP Application Default Credentials configured"
  else
    print_warning "GCP ADC not configured. Run: gcloud auth application-default login"
    has_errors=true
  fi
  
  # Check GitHub CLI authentication
  if gh auth status &>/dev/null; then
    local gh_account
    gh_account=$(gh auth status 2>&1 | grep "Logged in" | head -1 || echo "authenticated")
    print_success "GitHub CLI authenticated"
  else
    print_error "GitHub CLI not authenticated. Run: gh auth login"
    has_errors=true
  fi
  
  # Check git remote (assume valid if exists)
  if git remote get-url origin &>/dev/null; then
    print_success "Git remote: $(git remote get-url origin)"
  else
    print_warning "No git remote 'origin' configured (optional for this setup)"
  fi
  
  if [ "$has_errors" = true ]; then
    echo ""
    print_error "Please fix authentication issues and try again."
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Set and validate GCP project
# -----------------------------------------------------------------------------
set_and_validate_project() {
  local project_id="$1"
  
  print_step "Setting and Validating GCP Project"
  
  # Set the active project
  echo "Setting active GCP project to: $project_id"
  if ! gcloud config set project "$project_id" 2>/dev/null; then
    print_error "Failed to set GCP project to: $project_id"
    exit 1
  fi
  print_success "Active GCP project set to: $project_id"
  
  # Verify we can access the project
  echo "Verifying project access..."
  if ! gcloud projects describe "$project_id" &>/dev/null; then
    print_warning "Project '$project_id' does not exist or is not accessible"
    echo ""
    echo -e "${YELLOW}Would you like to create this project?${NC}"
    read -p "Create project '$project_id'? (y/N) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Project creation declined. Exiting."
      exit 1
    fi
    
    # Create the project
    echo "Creating GCP project: $project_id"
    if gcloud projects create "$project_id" --set-as-default; then
      print_success "Successfully created project: $project_id"
    else
      print_error "Failed to create project: $project_id"
      echo ""
      echo "Possible reasons:"
      echo "  - Project ID already exists globally (try a different ID)"
      echo "  - You don't have permission to create projects"
      echo "  - Organization policy restrictions"
      echo ""
      exit 1
    fi
  else
    print_success "Successfully verified access to project: $project_id"
  fi
}

# -----------------------------------------------------------------------------
# Check and enable billing
# -----------------------------------------------------------------------------
check_and_enable_billing() {
  local project_id="$1"
  
  print_step "Checking Billing Status"
  
  # Check if billing is enabled
  local billing_account
  billing_account=$(gcloud billing projects describe "$project_id" --format="value(billingAccountName)" 2>/dev/null || echo "")
  
  if [ -z "$billing_account" ]; then
    print_warning "Billing is not enabled for project: $project_id"
    echo ""
    echo -e "${YELLOW}This project requires billing to be enabled.${NC}"
    echo ""
    echo "You need to:"
    echo "  1. Go to: https://console.cloud.google.com/billing/linkedaccount?project=$project_id"
    echo "  2. Link a billing account to this project"
    echo "  3. Come back and press Enter to continue"
    echo ""
    read -p "Press Enter once billing is enabled..." -r
    
    # Verify billing is now enabled
    billing_account=$(gcloud billing projects describe "$project_id" --format="value(billingAccountName)" 2>/dev/null || echo "")
    
    if [ -z "$billing_account" ]; then
      print_error "Billing still not enabled. Please enable billing and try again."
      exit 1
    fi
    
    print_success "Billing is now enabled"
  else
    print_success "Billing is enabled (Account: $billing_account)"
  fi
}

# -----------------------------------------------------------------------------
# Main setup flow
# -----------------------------------------------------------------------------
main() {
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           AI Web Component - Full Infrastructure Setup            ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
  
  # Validate prerequisites and auth
  validate_prerequisites
  validate_authentication
  
  # Derive or use provided PROJECT_ID
  if [ -n "$1" ]; then
    PROJECT_ID="$1"
    print_success "Using provided PROJECT_ID: $PROJECT_ID"
  else
    # Derive default from repository
    DEFAULT_PROJECT_ID=$(derive_project_id)
    echo ""
    echo -e "${YELLOW}Enter GCP Project ID${NC}"
    read -p "Project ID [$DEFAULT_PROJECT_ID]: " PROJECT_ID
    
    # Use default if user just hit enter
    if [ -z "$PROJECT_ID" ]; then
      PROJECT_ID="$DEFAULT_PROJECT_ID"
    fi
    
    print_success "Using PROJECT_ID: $PROJECT_ID"
  fi
  
  # Set and validate GCP project immediately
  set_and_validate_project "$PROJECT_ID"
  
  # Check and enable billing
  check_and_enable_billing "$PROJECT_ID"
  
  # Set region
  REGION="${2:-us-central1}"
  print_success "Using REGION: $REGION"
  
  # Get GitHub repository
  GITHUB_REPO=$(get_github_repo)
  if [ -n "$GITHUB_REPO" ]; then
    print_success "GitHub repository: $GITHUB_REPO"
  else
    print_warning "Could not determine GitHub repository (optional)"
    GITHUB_REPO=""
  fi
  
  # Confirm before proceeding
  echo ""
  echo -e "${YELLOW}This will set up the following:${NC}"
  echo "  - GCP Project: $PROJECT_ID"
  echo "  - Region: $REGION"
  if [ -n "$GITHUB_REPO" ]; then
    echo "  - GitHub Repo: $GITHUB_REPO"
  fi
  echo ""
  read -p "Continue? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  
  # -----------------------------------------------------------------------------
  # Step 00: Initialize GCP Project
  # -----------------------------------------------------------------------------
  print_step "Step 00: Initialize GCP Project"
  bash scripts/00-init-project.sh "$PROJECT_ID" "$REGION"
  print_success "GCP project initialized"
  
  # -----------------------------------------------------------------------------
  # Step 01: Deploy GitHub Provider (Workload Identity Federation)
  # -----------------------------------------------------------------------------
  print_step "Step 01: Deploy GitHub Provider (WIF)"
  bash scripts/01-deploy-github-provider.sh "$PROJECT_ID" "$GITHUB_REPO"
  print_success "GitHub provider deployed"
  
  # -----------------------------------------------------------------------------
  # Step 01a: Push Secrets to GitHub
  # -----------------------------------------------------------------------------
  print_step "Step 01a: Push Secrets to GitHub"
  bash scripts/01a-setup-github-secrets.sh "$PROJECT_ID"
  print_success "GitHub secrets configured"
  
  # Create GitHub environment if it doesn't exist
  echo "Creating GitHub environment 'rapid-prototype'..."
  gh api repos/"$GITHUB_REPO"/environments/rapid-prototype -X PUT -F wait_timer=0 2>/dev/null || \
    print_warning "Could not create environment (may already exist or require admin permissions)"
  
  # -----------------------------------------------------------------------------
  # Step 02: Deploy Development Infrastructure
  # -----------------------------------------------------------------------------
  print_step "Step 02: Deploy Development Infrastructure"
  bash scripts/02-dev-infrastructure.sh "$PROJECT_ID" "$REGION"
  print_success "Development infrastructure deployed"
  
  # -----------------------------------------------------------------------------
  # Step 05: Setup Google AI Studio API Key
  # -----------------------------------------------------------------------------
  print_step "Step 05: Setup Google AI Studio API Key"
  bash scripts/05-setup-google-ai-studio-api-key.sh "$PROJECT_ID"
  print_success "AI Studio API key configured"
  
  # -----------------------------------------------------------------------------
  # Step 06: Build and Deploy API
  # -----------------------------------------------------------------------------
  print_step "Step 06: Build and Deploy API"
  cd application/chat-interface
  bash publish-build.sh "$PROJECT_ID" "$REGION" "chat-service"
  cd ../..
  print_success "API built and published to Artifact Registry"
  
  # -----------------------------------------------------------------------------
  # Step 04: Deploy Application Infrastructure (Cloud Run)
  # -----------------------------------------------------------------------------
  print_step "Step 04: Deploy Application Infrastructure"
  bash scripts/04-app-infrastructure.sh "$PROJECT_ID" "$REGION"
  print_success "Application infrastructure deployed"
  
  # -----------------------------------------------------------------------------
  # Step 07: Deploy Client (SPA)
  # -----------------------------------------------------------------------------
  print_step "Step 07: Deploy Client (SPA)"
  BUCKET_NAME="${PROJECT_ID}-spa"
  cd application/test-application
  bash upload-to-cloud-storage.sh "$BUCKET_NAME"
  cd ../..
  print_success "SPA deployed to Cloud Storage"
  
  # -----------------------------------------------------------------------------
  # Done!
  # -----------------------------------------------------------------------------
  
  # Get the Cloud Run service URL
  CHAT_SERVICE_URL=$(gcloud run services describe chat-service \
    --platform managed \
    --region "$REGION" \
    --format 'value(status.url)' 2>/dev/null || echo "https://chat-service-<hash>.run.app")
  
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                      Setup Complete!                              ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Your AI Web Component is now deployed!"
  echo ""
  echo -e "${BLUE}=== Deployment Information ===${NC}"
  echo ""
  echo "GCP Project:"
  echo "  Project ID: $PROJECT_ID"
  echo "  Region: $REGION"
  echo ""
  echo "Resources:"
  echo "  Cloud Run API: $CHAT_SERVICE_URL"
  echo "  Cloud Storage SPA: https://storage.googleapis.com/${BUCKET_NAME}/index.html"
  echo "  GitHub Repository: https://github.com/$GITHUB_REPO"
  echo "  GitHub Actions: https://github.com/$GITHUB_REPO/actions"
  echo ""
  echo "GitHub Secrets (already configured):"
  echo "  ✓ PROJECT_ID"
  echo "  ✓ PROJECT_NUMBER"
  echo "  ✓ SERVICE_ACCOUNT_EMAIL"
  echo "  ✓ WORKLOAD_IDENTITY_POOL_ID"
  echo "  ✓ WORKLOAD_IDENTITY_POOL_PROVIDER_ID"
  echo ""
  echo "Environment:"
  echo "  GitHub Environment: rapid-prototype"
  echo ""
  echo "Next steps:"
  echo "  1. Test the SPA at: https://storage.googleapis.com/${BUCKET_NAME}/index.html"
  echo "  2. Test the API at: $CHAT_SERVICE_URL"
  echo "  3. Push changes to main branch to trigger CI/CD"
  echo "  4. Customize the web component and API as needed"
  echo ""
}

# Run main
main "$@"
