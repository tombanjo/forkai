output "spa_bucket_url" {
  description = "The public URL of the SPA bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.spa.name}"
}
