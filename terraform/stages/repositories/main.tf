terraform {
  backend "gcs" {
    bucket         = "terraform-remote-state-my-gcp-project"
    prefix         = "dev/terraform/state/repositories"
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

locals {
  cors_origin = "https://storage.googleapis.com/${google_storage_bucket.spa.name}"
}

# ========== Artifact Registry ==========
resource "google_artifact_registry_repository" "service_repo" {
  location      = var.region
  repository_id = var.service_name
  description   = "Docker repo for Cloud Run chat service"
  format        = "DOCKER"
}

# ========== Static SPA Bucket ==========
resource "google_storage_bucket" "spa" {
  name                        = var.spa_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "google_storage_bucket_iam_member" "spa_public" {
  bucket = google_storage_bucket.spa.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
