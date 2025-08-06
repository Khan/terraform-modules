# Outputs for the Scheduled Cloud Function module

output "function_name" {
  description = "Name of the Cloud Function"
  value       = google_cloudfunctions2_function.function.name
}

output "function_url" {
  description = "URL of the Cloud Function"
  value       = google_cloudfunctions2_function.function.service_config[0].uri
}

output "service_account_email" {
  description = "Email of the service account used by the function"
  value       = google_service_account.function_sa.email
}

output "service_account_id" {
  description = "Full resource ID of the service account"
  value       = google_service_account.function_sa.name
}

output "pubsub_topic_name" {
  description = "Name of the PubSub topic that triggers the function"
  value       = google_pubsub_topic.function_topic.name
}

output "pubsub_topic_id" {
  description = "Full resource ID of the PubSub topic"
  value       = google_pubsub_topic.function_topic.id
}

output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job"
  value       = google_cloud_scheduler_job.function_scheduler.name
}

output "storage_bucket_name" {
  description = "Name of the storage bucket containing function source"
  value       = google_storage_bucket.function_bucket.name
}

output "function_project_id" {
  description = "Project ID where the function is deployed"
  value       = var.project_id
}

output "function_region" {
  description = "Region where the function is deployed"
  value       = var.region
} 