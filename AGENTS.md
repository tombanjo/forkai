# Agents Guide (Codegen/Dev Optimized)

## Development Workflow

This is a **cloud-driven app**. The primary development loop is:

1. Make code changes
2. Commit and push to a branch
3. Open a PR targeting `main` (triggers CI workflow)
4. Merge to `main` (triggers deployment via GitHub Actions)

**Do not rely on local testing as the primary e2e validation method.** The cloud environment is the source of truth.

## Repo Map

- `application/chat-interface/`: Node.js/Express API (deployed to Cloud Run)
- `application/test-application/`: static SPA demo (deployed to GCS)
- `scripts/`: infrastructure management scripts (run these, not Terraform directly)
- `terraform/`: Terraform modules (referenced by scripts, not run directly)
- `.github/workflows/`: GitHub Actions for automated deployments

## CI/CD Triggers

- `.github/workflows/chat-interface.yaml` — triggers on `application/chat-interface/**` changes
- `.github/workflows/test-application.yaml` — triggers on `application/test-application/**` changes

Both workflows run on pushes to `main` and on pull requests.

## Infrastructure Management

Infra changes are managed through `scripts/`, which wrap the Terraform modules in `terraform/`. **Run scripts, not Terraform commands directly.**

| Script | Purpose | Notes |
|--------|---------|-------|
| `00-init-project.sh` | Bootstrap GCP project | Non-Terraform (gcloud commands) |
| `01-deploy-github-provider.sh` | GitHub WIF identity provider | Non-Terraform (gcloud commands) |
| `02-dev-infrastructure.sh` | Base infrastructure | Terraform-backed |
| `03-app-publish.sh` | Publish app artifacts | Non-Terraform |
| `04-app-infrastructure.sh` | Cloud Run service config | Terraform-backed |
| `05-setup-google-ai-studio-api-key.sh` | AI Studio API key/secret | Non-Terraform (Secret Manager) |
| `06-app-deploy-api.sh` | Deploy API to Cloud Run | Non-Terraform |
| `07-app-deploy-client.sh` | Deploy SPA to GCS | Non-Terraform |

### Terraform Layout

- `terraform/stages/github-provider/`: WIF setup for GitHub Actions
- `terraform/stages/repositories/`: Artifact Registry + GCS buckets
- `terraform/stages/prototype/`: Cloud Run service configuration

## Local Development (Optional)

For quick iteration before pushing:

- **API**: `cd application/chat-interface && npm install && npm start`
- **SPA**: `cd application/test-application && python3 -m http.server 8000`
- **Auth**: `gcloud auth application-default login`
- **API env vars**:
  - `GOOGLE_CLOUD_PROJECT`
  - `GOOGLE_CLOUD_REGION`
  - `MODEL_NAME`
  - `CORS_ALLOWED_ORIGIN`
  - `MODEL_PROVIDER`
  - `GOOGLE_AI_STUDIO_API_SECRET`

## Codegen Guardrails

- Prefer editing only files in your task scope; avoid unrelated refactors.
- Keep API shape stable unless explicitly requested.
- For infra changes, update `terraform/` and matching `scripts/` together.
- Do not add service account keys; rely on ADC or Workload Identity Federation.
- Document new env vars in this file and `README.md` when introduced.

## Auth Notes

- **CI/CD**: Workload Identity Federation (no long-lived keys)
- **Local dev**: Application Default Credentials

## Suggested Agent Focus Areas

- **Infra agent**: `terraform/` and `scripts/`
- **API agent**: `application/chat-interface/`
- **Frontend agent**: `application/test-application/`
