# GitHub Actions to Google Cloud Authentication Module

This Terraform module sets up Workload Identity Federation between GitHub Actions and Google Cloud, allowing GitHub Actions workflows to authenticate with Google Cloud using short-lived tokens.

## Usage

```hcl
module "github_actions_auth" {
  source = "./github-provider"

  project_id    = "your-project-id"
  github_repository = "owner/repo"
}
```

## Required Variables

- `project_id` - The Google Cloud project ID
- `github_repository` - The GitHub repository in the format 'owner/repo'

## Optional Variables

- `service_account_id` - The ID of the service account to create (default: "github-actions")
- `workload_identity_pool_id` - The ID of the Workload Identity Pool (default: "github-actions-pool")
- `workload_identity_pool_provider_id` - The ID of the Workload Identity Pool Provider (default: "github-actions-provider")

## Outputs

- `service_account_email` - The email of the service account created for GitHub Actions
- `workload_identity_pool_id` - The ID of the Workload Identity Pool
- `workload_identity_pool_provider_id` - The ID of the Workload Identity Pool Provider
- `workload_identity_pool_name` - The full name of the Workload Identity Pool

## GitHub Actions Workflow Example

To use this in your GitHub Actions workflow, add the following authentication step:

```yaml
on:
  push:
    branches:
      - main
  workflow_dispatch:
    
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: rapid-prototype
    permissions:
      contents: 'read'
      id-token: 'write'
    
    steps:
      - uses: 'actions/checkout@v3'
      
      - id: 'auth'
        name: 'Authenticate to Google Cloud'
        uses: 'google-github-actions/auth@v1'
        with:
          workload_identity_provider: 'projects/${{ secrets.PROJECT_ID }}/locations/global/workloadIdentityPools/${{ secrets.WORKLOAD_IDENTITY_POOL_ID }}/providers/${{ secrets.WORKLOAD_IDENTITY_POOL_PROVIDER_ID }}'
          service_account: ${{ secrets.SERVICE_ACCOUNT_EMAIL }}
      
      - id: 'verify-auth'
        name: 'Verify Authentication'
        run: |
          gcloud auth list
          gcloud projects list
```

## Prerequisites

1. You must be logged in to Google Cloud (`gcloud auth login`)
2. You must have the necessary permissions to create service accounts and IAM resources
3. The Google Cloud provider must be configured with appropriate credentials 