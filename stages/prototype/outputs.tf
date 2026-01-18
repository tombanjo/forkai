output "chat_service_url" {
  description = "The URL of the deployed chat service"
  value       = google_cloud_run_service.service.status[0].url
}
