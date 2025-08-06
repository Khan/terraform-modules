# Outputs from the GitHub Terraform CI Bootstrap module

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
  value       = "projects/${data.google_project.khan_internal_services.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_ci_provider.workload_identity_pool_provider_id}"
}

output "workload_identity_pool_id" {
  description = "ID of the shared Workload Identity pool"
  value       = google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id
}

output "workload_identity_provider_id" {
  description = "ID of the Workload Identity provider for this service"
  value       = google_iam_workload_identity_pool_provider.github_ci_provider.workload_identity_pool_provider_id
}

output "terraform_state_bucket" {
  description = "The GCS bucket name used for Terraform state (computed or provided)"
  value       = local.terraform_state_bucket
}

output "service_name" {
  description = "The Terraform setup name used for this CI configuration"
  value       = var.service_name
}

output "github_repository" {
  description = "The GitHub repository configured for Workload Identity"
  value       = var.github_repository
}

output "target_projects" {
  description = "Map of target projects configured for this service account"
  value       = var.target_projects
} 