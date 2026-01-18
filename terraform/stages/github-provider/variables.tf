variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "github_repository" {
  description = "The GitHub repository in the format 'owner/repo'"
  type        = string
}

variable "service_account_id" {
  description = "The ID of the service account to create"
  type        = string
  default     = "github-actions"
}

variable "workload_identity_pool_id" {
  description = "The ID of the Workload Identity Pool"
  type        = string
  default     = "github-actions-pool-ai-startup"
}

variable "workload_identity_pool_provider_id" {
  description = "The ID of the Workload Identity Pool Provider"
  type        = string
  default     = "github-actions-provider"
}