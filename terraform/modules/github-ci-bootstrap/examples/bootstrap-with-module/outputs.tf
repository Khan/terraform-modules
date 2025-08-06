# Outputs from the bootstrap example

output "service_account_email" {
  description = "Email address of the created service account for GitHub Actions"
  value       = module.culture_cron_bootstrap.service_account_email
}

output "workload_identity_provider" {
  description = "Full resource name of the Workload Identity provider for GitHub Actions"
  value       = module.culture_cron_bootstrap.workload_identity_provider
}

output "project_id" {
  description = "The project ID where resources were created"
  value       = module.culture_cron_bootstrap.project_id
}

output "github_repository" {
  description = "The GitHub repository configured for Workload Identity"
  value       = module.culture_cron_bootstrap.github_repository
} 