variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "The region for deployment"
  type        = string
}

variable "service_name" {
  description = "The container image for the service"
  type        = string
}

variable "spa_bucket_name" {
  description = "The name of the Google Cloud Storage bucket for the SPA"
  type        = string
}