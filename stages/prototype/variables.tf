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

variable "cors_origin" {
  description = "The CORS origins for the Cloud Run service"
  type        = string
}

variable "model_name" {
  description = "The Gemini model name to use (e.g., gemini-2.0-flash-lite)"
  type        = string
  default     = "gemini-2.0-flash-lite"
}

variable "google_ai_studio_secret_name" {
  description = "The Secret Manager secret name containing the Google AI Studio API key"
  type        = string
  default     = "gemini-api-key-secret"
}