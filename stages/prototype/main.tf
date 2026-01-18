terraform {
  backend "gcs" {
    bucket         = "terraform-remote-state-my-gcp-project"
    prefix         = "dev/terraform/state/prototype"
  }
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Project + basic config
data "google_project" "project" {}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ========== Cloud Run ==========

resource "google_cloud_run_service" "service" {
  name     = var.service_name
  location = var.region

  template {
    spec {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.service_name}/${var.service_name}:latest"
        ports {
          container_port = 8080
        }
        env {
          name  = "CORS_ALLOWED_ORIGIN"
          value = var.cors_origin
        }
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
        env {
          name  = "GOOGLE_CLOUD_REGION"
          value = var.region
        }
        env {
          name  = "MODEL_NAME"
          value = var.model_name
        }
        env {
          name  = "GOOGLE_AI_STUDIO_API_SECRET"
          value = var.google_ai_studio_secret_name
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}

# Allow unauthenticated access to Cloud Run
resource "google_cloud_run_service_iam_member" "run_invoker" {
  service  = google_cloud_run_service.service.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Vertex AI IAM permissions - grants service account access to Vertex AI
resource "google_project_iam_member" "cloudrun_vertexai_access" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Secret Manager access - grants service account access to the Google AI Studio API key secret
resource "google_secret_manager_secret_iam_member" "cloudrun_secret_access" {
  secret_id = var.google_ai_studio_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}