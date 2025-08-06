# Example: Culture Cron Bootstrap using Remote Module
# This demonstrates how to use the GitHub CI bootstrap module from the shared repository

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
    bucket = "terraform-khan-academy"
    prefix = "culture-cron-bootstrap-example"
  }
}

# Google Cloud provider for the bootstrap resources
provider "google" {
  project = var.project_id
  region  = var.region
}

# Use the GitHub CI bootstrap module from the shared repository
module "culture_cron_bootstrap" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=main"

  # Project configuration
  google_project_name  = var.project_id
  project_name         = "culture-cron"
  project_display_name = "Culture Cron"

  # GitHub configuration
  github_repository = "Khan/culture-cron"

  # Terraform state
  terraform_state_bucket = "terraform-khan-academy"

  # Services needed for culture-cron
  required_services = ["cloudfunctions", "storage", "pubsub", "scheduler"]

  # Secrets configuration
  secrets_project_id = var.secrets_project_id
  secret_ids = [
    "projects/${var.secrets_project_id}/secrets/districts_slack_token"
  ]
} 