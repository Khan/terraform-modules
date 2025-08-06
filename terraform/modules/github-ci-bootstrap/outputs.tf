# Outputs from the GitHub CI Bootstrap module

output "service_account_email" {
  description = "Email address of the created service account for GitHub Actions"
  value       = google_service_account.github_ci.email
}

output "service_account_name" {
  description = "Full resource name of the created service account"
  value       = google_service_account.github_ci.name
}

output "workload_identity_provider" {
  description = "Full resource name of the Workload Identity provider for GitHub Actions"
  value       = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_ci_provider.workload_identity_pool_provider_id}"
}

output "workload_identity_pool_id" {
  description = "ID of the Workload Identity pool"
  value       = google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id
}

output "workload_identity_provider_id" {
  description = "ID of the Workload Identity provider"
  value       = google_iam_workload_identity_pool_provider.github_ci_provider.workload_identity_pool_provider_id
}

output "project_id" {
  description = "The project ID where resources were created"
  value       = var.google_project_name
}

output "github_repository" {
  description = "The GitHub repository configured for Workload Identity"
  value       = var.github_repository
} 