# Outputs from the GitHub Terraform CI Bootstrap module

output "service_account_email_rw" {
  description = "Email address of the read-write service account for GitHub Actions (write-enabled branches)"
  value       = google_service_account.github_ci_rw.email
}

output "service_account_name_rw" {
  description = "Full resource name of the read-write service account (write-enabled branches)"
  value       = google_service_account.github_ci_rw.name
}

output "service_account_email_ro" {
  description = "Email address of the read-only service account for GitHub Actions (available to any branch)"
  value       = google_service_account.github_ci_ro.email
}

output "service_account_name_ro" {
  description = "Full resource name of the read-only service account (available to any branch)"
  value       = google_service_account.github_ci_ro.name
}

output "workload_identity_provider_rw" {
  description = "Full resource name of the read-write Workload Identity provider for GitHub Actions (write-enabled branches)"
  value       = "projects/${data.google_project.khan_internal_services.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_ci_provider_rw.workload_identity_pool_provider_id}"
}

output "workload_identity_provider_ro" {
  description = "Full resource name of the read-only Workload Identity provider for GitHub Actions (available to any branch)"
  value       = "projects/${data.google_project.khan_internal_services.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_ci_provider_ro.workload_identity_pool_provider_id}"
}

output "workload_identity_pool_id" {
  description = "ID of the shared Workload Identity pool"
  value       = google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id
}

output "workload_identity_provider_id_rw" {
  description = "ID of the read-write Workload Identity provider for this service (write-enabled branches)"
  value       = google_iam_workload_identity_pool_provider.github_ci_provider_rw.workload_identity_pool_provider_id
}

output "workload_identity_provider_id_ro" {
  description = "ID of the read-only Workload Identity provider for this service (available to any branch)"
  value       = google_iam_workload_identity_pool_provider.github_ci_provider_ro.workload_identity_pool_provider_id
}

output "terraform_state_bucket" {
  description = "The GCS bucket name used for Terraform state (computed or provided)"
  value       = local.terraform_state_bucket
}

output "service_name" {
  description = "The unique identifier for this Terraform configuration and environment managed in CI"
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


output "write_branch_patterns" {
  description = "List of branch patterns that are allowed to use the read/write service account"
  value       = var.write_branch_patterns
}

# Additional outputs for backward compatibility and clarity
output "terraform_service_account_email" {
  description = "Email address of the read-write service account (alias for service_account_email_rw)"
  value       = google_service_account.github_ci_rw.email
}

output "workload_identity_provider" {
  description = "Full resource name of the read-write Workload Identity provider (alias for workload_identity_provider_rw)"
  value       = "projects/${data.google_project.khan_internal_services.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_ci_provider_rw.workload_identity_pool_provider_id}"
} 