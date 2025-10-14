# Outputs for the Scheduled Cloud Function/Job module

output "resource_name" {
  description = "Name of the Cloud Function or Cloud Run Job"
  value       = var.execution_type == "function" ? google_cloudfunctions2_function.function[0].name : google_cloud_run_v2_job.job[0].name
}

output "function_url" {
  description = "URL of the Cloud Function (when execution_type is 'function')"
  value       = var.execution_type == "function" ? google_cloudfunctions2_function.function[0].service_config[0].uri : null
}

output "service_account_email" {
  description = "Email of the service account used by the function/job"
  value       = google_service_account.function_sa.email
}

output "service_account_id" {
  description = "Full resource ID of the service account"
  value       = google_service_account.function_sa.name
}

output "pubsub_topic_name" {
  description = "Name of the PubSub topic that triggers the function (when execution_type is 'function')"
  value       = var.execution_type == "function" ? google_pubsub_topic.function_topic[0].name : null
}

output "pubsub_topic_id" {
  description = "Full resource ID of the PubSub topic (when execution_type is 'function')"
  value       = var.execution_type == "function" ? google_pubsub_topic.function_topic[0].id : null
}

output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job"
  value       = var.execution_type == "function" ? google_cloud_scheduler_job.function_scheduler[0].name : google_cloud_scheduler_job.job_scheduler[0].name
}

output "storage_bucket_name" {
  description = "Name of the storage bucket containing function source (when execution_type is 'function')"
  value       = var.execution_type == "function" ? google_storage_bucket.function_bucket[0].name : null
}

output "project_id" {
  description = "Project ID where the function or job is deployed"
  value       = var.project_id
}

output "region" {
  description = "Region where the function or job is deployed"
  value       = var.region
}

output "execution_type" {
  description = "The execution type used (function or job)"
  value       = var.execution_type
}

# Alerting outputs
output "monitoring_notification_channel_name" {
  description = "Name of the monitoring notification channel (when alerting is enabled)"
  value       = var.enable_alerting ? google_monitoring_notification_channel.slack_channel[0].name : null
}

output "alert_policy_names" {
  description = "Names of the monitoring alert policies (when alerting is enabled)"
  value = var.enable_alerting ? {
    function_failure  = var.execution_type == "function" ? google_monitoring_alert_policy.function_failure[0].display_name : null
    job_failure       = var.execution_type == "job" ? google_monitoring_alert_policy.job_failure[0].display_name : null
  } : null
}
