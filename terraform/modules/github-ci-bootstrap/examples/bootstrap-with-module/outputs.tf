# Outputs from the bootstrap example

output "service_account_email_rw" {
  description = "Email address of the read-write service account for GitHub Actions (write-enabled branches)"
  value       = module.culture_cron_bootstrap.service_account_email_rw
}

output "service_account_email_ro" {
  description = "Email address of the read-only service account for GitHub Actions (available to any branch)"
  value       = module.culture_cron_bootstrap.service_account_email_ro
}

output "workload_identity_provider_rw" {
  description = "Full resource name of the read-write Workload Identity provider for GitHub Actions (write-enabled branches)"
  value       = module.culture_cron_bootstrap.workload_identity_provider_rw
}

output "workload_identity_provider_ro" {
  description = "Full resource name of the read-only Workload Identity provider for GitHub Actions (available to any branch)"
  value       = module.culture_cron_bootstrap.workload_identity_provider_ro
}

output "service_name" {
  description = "The unique identifier for this Terraform configuration and environment managed in CI"
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


output "write_branch_patterns" {
  description = "List of branch patterns that are allowed to use the read/write service account"
  value       = module.culture_cron_bootstrap.write_branch_patterns
} 