# Outputs from the bootstrap example

output "service_account_email" {
  description = "Email address of the created service account for GitHub Actions"
  value       = module.culture_cron_bootstrap.service_account_email
}

output "workload_identity_provider" {
  description = "Full resource name of the Workload Identity provider for GitHub Actions"
  value       = module.culture_cron_bootstrap.workload_identity_provider
}

output "service_name" {
  description = "The Terraform setup name used for this CI configuration"
  value       = module.culture_cron_bootstrap.service_name
}

output "github_repository" {
  description = "The GitHub repository configured for Workload Identity"
  value       = module.culture_cron_bootstrap.github_repository
}

output "target_projects" {
  description = "Map of target projects configured for this service account"
  value       = module.culture_cron_bootstrap.target_projects
} 