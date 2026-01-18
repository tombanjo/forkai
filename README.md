# AI Web Component

A white-label full-stack AI chat starter kit for rapid prototyping on GCP. Fork it, customize the model/UI, deploy to your own GCP project, and have a working AI-powered web app in minutes.

> **For AI Agents / Codegen Tools**: See [AGENTS.md](./AGENTS.md) for architecture overview, customization guide, and operational workflows.

## Overview

This repository contains a full-stack AI chat application built with:
- **Backend**: Node.js/Express API deployed on Google Cloud Run
- **Frontend**: Static web application with custom web components deployed on Google Cloud Storage
- **AI Integration**: Vertex AI (Gemini) for chat functionality with service account authentication
- **Infrastructure**: Terraform-managed Google Cloud resources
- **CI/CD**: GitHub Actions with Workload Identity Federation for secure deployments

## Architecture

The project consists of:

1. **Chat Interface API** (`application/chat-interface/`): Node.js Express server that handles chat requests and integrates with Google AI Studio (Gemini API)
2. **Test Application** (`application/test-application/`): Static HTML application demonstrating the AI chat web component
3. **Terraform Infrastructure** (`terraform/stages/`): Infrastructure as Code for:
   - GitHub Actions authentication (Workload Identity Federation)
   - Artifact Registry and Cloud Storage buckets
   - Cloud Run services

## Prerequisites

Before starting, ensure you have the following installed:

- **Bash**: Unix shell (included on macOS/Linux; use WSL or Git Bash on Windows)
- **Git**: For version control
- **GitHub CLI (gh)**: [Installation Guide](https://cli.github.com/) - for pushing secrets to GitHub
- **Node.js**: Version 18+ [Installation Guide](https://nodejs.org/)
- **Google Cloud SDK (gcloud)**: [Installation Guide](https://cloud.google.com/sdk/docs/install)
- **Terraform**: Version 1.0+ [Installation Guide](https://www.terraform.io/downloads)
- **Pack CLI** (for Cloud Native Buildpacks): [Installation Guide](https://buildpacks.io/docs/tools/pack/)
- **GitHub Account**: For repository hosting and CI/CD

## Before You Begin: Authenticate

Before running any setup scripts, authenticate to both GCP and GitHub:

### 1. Authenticate to Google Cloud

```bash
# Login to GCP
gcloud auth login

# Set up Application Default Credentials (for local development and scripts)
gcloud auth application-default login

# Verify authentication
gcloud auth list
```

### 2. Authenticate to GitHub CLI

```bash
# Login to GitHub (follow the prompts)
gh auth login

# Verify authentication
gh auth status
```

### 3. Set your GCP project

```bash
gcloud config set project YOUR_PROJECT_ID
```

## Quick Setup (Recommended)

For a fully automated setup, use the one-command setup script:

```bash
./setup.sh                      # Auto-derives project ID from git repo name
./setup.sh my-project           # Explicit project ID
./setup.sh my-project us-west1  # Explicit project ID and region
```

This script will:
1. Validate all prerequisites and authentication
2. Initialize the GCP project (Terraform state, APIs)
3. Deploy GitHub Workload Identity Federation
4. Push required secrets to GitHub
5. Deploy base infrastructure (Artifact Registry, GCS)
6. Deploy application infrastructure (Cloud Run)
7. Setup Google AI Studio API key
8. Build and deploy the API to Cloud Run
9. Upload the SPA to Cloud Storage

After completion, you'll have a fully working deployment ready for CI/CD.

---

## Manual Setup Procedures

If you prefer to run each step manually, follow the procedures below.

### Step 1: Create Google Cloud Project

1. **Create a new GCP project**:
   ```bash
   gcloud projects create your-project-id --name="AI Web Component"
   ```
   
   **Note**: Replace `your-project-id` with your actual project ID (e.g., `my-gcp-project`, `my-ai-project`). Project IDs must be globally unique.

   Or create it via the [Google Cloud Console](https://console.cloud.google.com/):
   - Go to "Select a project" → "New Project"
   - Enter project name and ID
   - Click "Create"

2. **Set the project as active**:
   ```bash
   gcloud config set project your-project-id
   ```
   
   **Note**: Replace `your-project-id` with your actual project ID.

3. **Enable billing** (required for Cloud Run and Vertex AI):
   - Go to [Billing](https://console.cloud.google.com/billing) in Cloud Console
   - Link a billing account to your project

### Step 2: Authenticate to Google Cloud

1. **Authenticate with your Google account**:
   ```bash
   gcloud auth login
   ```

2. **Set up Application Default Credentials** (for local development):
   ```bash
   gcloud auth application-default login
   ```

3. **Verify authentication**:
   ```bash
   gcloud auth list
   gcloud config get-value project
   ```

### Step 3: Initialize GCP Project Infrastructure

Run the initialization script to set up Terraform remote state and enable required APIs:

```bash
./scripts/00-init-project.sh [PROJECT_ID] [REGION]
```

**Parameters**:
- `PROJECT_ID` (optional): Your GCP project ID. Defaults to `my-gcp-project`
- `REGION` (optional): GCP region. Defaults to `us-central1`

**What it does**:
- Creates a Google Cloud Storage bucket for Terraform remote state
- Sets up folders for different deployment stages (dev, staging, prod)
- Enables required APIs:
  - Storage API
  - IAM Credentials API
  - Cloud Resource Manager API
  - Artifact Registry API
  - Cloud Run API
  - Vertex AI Platform API (for future use if switching back to Vertex AI)

**Example**:
```bash
./scripts/00-init-project.sh my-ai-project us-central1
```

### Step 4: Create GitHub Repository

1. **Create a new repository on GitHub**:
   - Go to [GitHub](https://github.com/new)
   - Choose a repository name (e.g., `ai-web-component`)
   - Set visibility (public or private)
   - **Do NOT** initialize with README, .gitignore, or license (if you're pushing existing code)

2. **Push your code to GitHub**:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
   git push -u origin main
   ```

### Step 5: Deploy GitHub Provider (Workload Identity Federation)

This sets up secure authentication between GitHub Actions and Google Cloud:

```bash
./scripts/01-deploy-github-provider.sh [PROJECT_ID] [GITHUB_REPOSITORY]
```

**Parameters**:
- `PROJECT_ID` (optional): Your GCP project ID. Defaults to `my-gcp-project`
- `GITHUB_REPOSITORY` (optional): Repository in format `owner/repo`. Defaults to `tombanjo/ai-web-component`

**What it does**:
- Creates a Workload Identity Pool for GitHub Actions
- Creates a Workload Identity Pool Provider
- Creates a service account for GitHub Actions
- Grants necessary permissions

**Example**:
```bash
./scripts/01-deploy-github-provider.sh my-ai-project myusername/ai-web-component
```

**Note**: The script will attempt to import existing resources if they already exist in GCP.

### Step 6: Configure GitHub Repository Secrets

After running the GitHub provider script, you'll need to capture the outputs and set them as GitHub secrets.

1. **Get Terraform outputs**:
   ```bash
   cd terraform/stages/github-provider
   terraform output
   ```

   You should see outputs like:
   - `service_account_email`
   - `workload_identity_pool_id`
   - `workload_identity_pool_provider_id`

2. **Get your GCP Project Number**:
   ```bash
   gcloud projects describe your-project-id --format="value(projectNumber)"
   ```
   
   **Note**: Replace `your-project-id` with your actual project ID. This will output a numeric project number that you'll need for GitHub secrets.

3. **Set GitHub Secrets**:
   - Go to your GitHub repository
   - Navigate to **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret** for each of the following:

   | Secret Name | Value | Description |
   |------------|-------|-------------|
   | `PROJECT_ID` | Your GCP project ID | e.g., `my-ai-project` |
   | `PROJECT_NUMBER` | Your GCP project number | From `gcloud projects describe` |
   | `SERVICE_ACCOUNT_EMAIL` | Service account email | From Terraform output |
   | `WORKLOAD_IDENTITY_POOL_ID` | Pool ID | From Terraform output (usually `github-actions-pool`) |
   | `WORKLOAD_IDENTITY_POOL_PROVIDER_ID` | Provider ID | From Terraform output (usually `github-actions-provider`) |

4. **Create GitHub Environment** (if not exists):
   - Go to **Settings** → **Environments**
   - Create environment named `rapid-prototype` (or update workflow files to use a different name)

### Step 7: Deploy Development Infrastructure

Deploy the base infrastructure (Artifact Registry, Cloud Storage buckets):

```bash
./scripts/02-dev-infrastructure.sh [PROJECT_ID] [REGION] [BUCKET_NAME] [SERVICE_NAME]
```

**Parameters**:
- `PROJECT_ID` (optional): Defaults to `my-gcp-project`
- `REGION` (optional): Defaults to `us-central1`
- `BUCKET_NAME` (optional): Cloud Storage bucket name. Defaults to `ai-web-component`
- `SERVICE_NAME` (optional): Artifact Registry repository name. Defaults to `chat-service`

**What it does**:
- Creates an Artifact Registry repository for Docker images
- Creates a Cloud Storage bucket for static website hosting
- Configures bucket permissions for public access

**Example**:
```bash
./scripts/02-dev-infrastructure.sh my-ai-project us-central1 my-ai-bucket chat-service
```

### Step 9: Deploy Application Infrastructure

Deploy the Cloud Run service infrastructure:

```bash
./scripts/04-app-infrastructure.sh [PROJECT_ID] [REGION] [CORS_ORIGIN] [SERVICE_NAME]
```

**Parameters**:
- `PROJECT_ID` (optional): Defaults to `my-gcp-project`
- `REGION` (optional): Defaults to `us-central1`
- `CORS_ORIGIN` (optional): CORS allowed origin. Defaults to `https://storage.googleapis.com`
- `SERVICE_NAME` (optional): Cloud Run service name. Defaults to `chat-service`
- `MODEL_NAME` (optional): Gemini model name. Defaults to `gemini-3.0-flash-exp`

**What it does**:
- Creates a Cloud Run service configuration
- Sets up IAM permissions for unauthenticated access
- Configures Vertex AI with service account authentication
- Grants Vertex AI access to the Cloud Run service account

**Example**:
```bash
./scripts/04-app-infrastructure.sh my-ai-project us-central1 https://storage.googleapis.com/my-ai-bucket chat-service gemini-3.0-flash-exp
```

**Note**: Uses service account authentication (Application Default Credentials) for service-to-service authentication. IAM permissions are automatically configured via Terraform. No API keys needed!

## Running Projects Locally

### Chat Interface API

1. **Navigate to the chat interface directory**:
   ```bash
   cd application/chat-interface
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Set environment variables**:
   ```bash
   export PORT=8080
   export CORS_ALLOWED_ORIGIN=http://localhost:3000
   export MODEL_NAME=gemini-3.0-flash-exp
   export GOOGLE_CLOUD_PROJECT=your-project-id
   export GOOGLE_CLOUD_REGION=us-central1
   ```
   
   **Note**: Uses Application Default Credentials (ADC) for authentication. For local development, run `gcloud auth application-default login` to set up credentials.

4. **Run the server**:
   ```bash
   npm start
   # or
   node index.js
   ```

   The server will start on `http://localhost:8080`

5. **Test the API**:
   ```bash
   curl -X POST http://localhost:8080 \
     -H "Content-Type: application/json" \
     -d '{"message": "Hello, AI!"}'
   ```

### Test Application (Frontend)

1. **Navigate to the test application directory**:
   ```bash
   cd application/test-application
   ```

2. **Serve the application locally**:
   
   Using Python:
   ```bash
   python3 -m http.server 8000
   ```
   
   Using Node.js (http-server):
   ```bash
   npx http-server -p 8000
   ```

3. **Open in browser**:
   Navigate to `http://localhost:8000`

   **Note**: The web component will need to be configured to point to your local API endpoint or deployed Cloud Run service.

## Deployment Scripts

### Publishing Applications

#### Publish Chat Interface Build

Builds and publishes the Docker image to Artifact Registry:

```bash
cd application/chat-interface
./publish-build.sh [PROJECT_ID] [REGION] [SERVICE_NAME]
```

**Parameters**:
- `PROJECT_ID` (optional): Defaults to `my-gcp-project`
- `REGION` (optional): Defaults to `us-central1`
- `SERVICE_NAME` (optional): Defaults to `chat-service`

**What it does**:
- Uses Cloud Native Buildpacks to build a container image
- Publishes the image to Artifact Registry

#### Deploy Chat Interface to Cloud Run

Deploys the published image to Cloud Run:

```bash
cd application/chat-interface
./deploy-to-cloud-run.sh [PROJECT_ID] [REGION] [SERVICE_NAME]
```

**Parameters**: Same as `publish-build.sh`

#### Upload Test Application to Cloud Storage

Uploads the static files to Cloud Storage:

```bash
cd application/test-application
./upload-to-cloud-storage.sh [BUCKET_NAME]
```

**Parameters**:
- `BUCKET_NAME` (optional): Defaults to `ai-web-component`

### Complete Deployment Workflows

#### Deploy API (Chat Interface)

Combines publishing and deployment:

```bash
./scripts/05-app-deploy-api.sh
```

This script:
1. Publishes the Docker image
2. Deploys to Cloud Run

#### Deploy Client (Test Application)

Uploads the static application:

```bash
./scripts/06-app-deploy-client.sh
```

#### Publish All Applications

Publishes both applications:

```bash
./scripts/03-app-publish.sh
```

This script:
1. Uploads test application to Cloud Storage
2. Publishes chat interface build

## CI/CD with GitHub Actions

The repository includes GitHub Actions workflows for automated deployment:

### Workflows

1. **`.github/workflows/chat-interface.yaml`**:
   - Triggers on changes to `application/chat-interface/**`
   - Builds and deploys the chat API to Cloud Run

2. **`.github/workflows/test-application.yaml`**:
   - Triggers on changes to `application/test-application/**`
   - Uploads the static application to Cloud Storage

3. **`.github/workflows/gcloud-test.yaml`**:
   - Manual workflow for testing GCP authentication

### How It Works

1. **Workload Identity Federation**: GitHub Actions authenticates to GCP using short-lived tokens (no service account keys needed)
2. **Automatic Deployment**: On push to `main` branch, relevant workflows trigger automatically
3. **Manual Trigger**: Workflows can also be triggered manually via GitHub Actions UI

## Cleanup

To destroy the prototype infrastructure:

```bash
./scripts/99-destroy-prototype.sh [PROJECT_ID] [REGION] [BUCKET_NAME] [SERVICE_NAME]
```

**Warning**: This will destroy all resources managed by the prototype Terraform configuration.

## Project Structure

```
ai-startup/
├── setup.sh                     # One-command full infrastructure setup
├── application/
│   ├── chat-interface/          # Node.js API for chat functionality
│   │   ├── index.js             # Express server with Vertex AI integration
│   │   ├── package.json
│   │   ├── publish-build.sh     # Build and publish Docker image
│   │   └── deploy-to-cloud-run.sh  # Deploy to Cloud Run
│   └── test-application/        # Static web application
│       ├── index.html           # Demo HTML page
│       ├── web-component/       # Custom web components
│       └── upload-to-cloud-storage.sh  # Upload to GCS
├── scripts/                     # Deployment automation scripts
│   ├── 00-init-project.sh      # Initialize GCP project
│   ├── 01-deploy-github-provider.sh  # Set up GitHub Actions auth
│   ├── 01a-setup-github-secrets.sh   # Push secrets to GitHub
│   ├── 02-dev-infrastructure.sh      # Deploy base infrastructure
│   ├── 03-app-publish.sh       # Publish all applications
│   ├── 04-app-infrastructure.sh      # Deploy app infrastructure
│   ├── 05-setup-google-ai-studio-api-key.sh  # API key setup
│   ├── 06-app-deploy-api.sh    # Deploy API
│   ├── 07-app-deploy-client.sh # Deploy client
│   └── 99-destroy-prototype.sh # Cleanup script
├── terraform/
│   └── stages/
│       ├── github-provider/     # Workload Identity Federation setup
│       ├── repositories/        # Artifact Registry and Cloud Storage
│       └── prototype/           # Cloud Run service configuration
└── .github/
    └── workflows/               # GitHub Actions workflows
```

## Technology Stack

- **Backend**: Node.js, Express, Vertex AI (Gemini)
- **Frontend**: HTML5, Web Components, Vanilla JavaScript
- **Infrastructure**: Google Cloud Platform (Cloud Run, Cloud Storage, Artifact Registry, Vertex AI)
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Container Build**: Cloud Native Buildpacks

## Troubleshooting

### Common Issues

1. **Authentication Errors**:
   - Ensure `gcloud auth login` and `gcloud auth application-default login` are completed
   - Verify project is set: `gcloud config get-value project`

2. **Terraform Backend Errors**:
   - Ensure the GCS bucket for remote state exists (run `00-init-project.sh` first)
   - Check bucket permissions

3. **GitHub Actions Authentication Fails**:
   - Verify all GitHub secrets are set correctly
   - Check that the environment `rapid-prototype` exists
   - Ensure the repository format matches (owner/repo)

4. **Cloud Run Deployment Fails**:
   - Verify Artifact Registry repository exists
   - Check that the image was published successfully
   - Ensure required APIs are enabled

5. **Vertex AI Access Denied**:
   - Verify GOOGLE_CLOUD_PROJECT and GOOGLE_CLOUD_REGION are set
   - Ensure Vertex AI API is enabled
   - Check IAM permissions for the compute service account (automatically configured by Terraform)
   - For local development, ensure Application Default Credentials are set: `gcloud auth application-default login`

## Additional Resources

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GitHub Actions Workload Identity Federation](https://github.com/google-github-actions/auth)

## License

See LICENSE file for details.
