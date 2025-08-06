# Example: Culture Cron GitHub Terraform CI Bootstrap using Remote Module
# This demonstrates how to use the GitHub Terraform CI bootstrap module from the shared repository

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
  }
  required_version = ">= 1.3.0"

  # Store Terraform state in GCS
  backend "gcs" {
    bucket = "terraform-khan-culture-cron-culture-cron-prod" # This will match the computed default
    prefix = "culture-cron-bootstrap-example"
  }
}

# Google Cloud provider for the bootstrap resources
provider "google" {
  project = var.project_id
  region  = var.region
}

# Use the GitHub Terraform CI bootstrap module from the shared repository
module "culture_cron_bootstrap" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  # Service configuration
  service_name      = "culture-cron-prod"
  github_repository = "Khan/culture-cron"

  # Target projects - culture-cron deploys to khan-internal-services
  target_projects = {
    (var.project_id) = {
      required_services = ["cloudfunctions", "storage", "pubsub", "scheduler"]
    }
  }

  # Terraform state bucket will default to: terraform-khan-culture-cron-culture-cron-prod
  # terraform_state_bucket = "custom-bucket-name"  # Uncomment to override default

  # Secrets configuration - uses khan-academy project by default
  secret_ids = [
    "projects/${var.secrets_project_id}/secrets/districts_slack_token"
  ]
} 