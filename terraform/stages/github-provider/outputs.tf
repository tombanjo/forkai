output "service_account_email" {
  description = "The email of the service account created for GitHub Actions"
  value       = google_service_account.github_actions.email
}

output "workload_identity_pool_id" {
  description = "The ID of the Workload Identity Pool"
  value       = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
}

output "workload_identity_pool_provider_id" {
  description = "The ID of the Workload Identity Pool Provider"
  value       = google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id
}

output "workload_identity_pool_name" {
  description = "The full name of the Workload Identity Pool"
  value       = google_iam_workload_identity_pool.github_pool.name
} 