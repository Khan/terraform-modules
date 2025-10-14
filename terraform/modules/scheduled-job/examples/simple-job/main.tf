# Simple example of using the scheduled function module with Cloud Run Jobs
# This shows the minimum configuration needed for a Cloud Run Job

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google" {
  alias   = "secrets"
  project = var.secrets_project_id
  region  = var.region
}

# Build the container image using Cloud Build
module "daily_data_processor_image" {
  # When used from another repository, this would be:
  # source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/cloud-build-docker?ref=v1.0.0"
  source = "../../../cloud-build-docker"

  image_name       = "daily-data-processor"
  context_path     = "./job-code"
  project_id       = var.project_id
  image_tag_suffix = "latest"
}

# Simple daily job example
module "daily_data_processor" {
  # When used from another repository, this would be:
  # source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  source = "../.."

  job_name           = "daily-data-processor"
  execution_type     = "job"
  project_id         = var.project_id
  secrets_project_id = var.secrets_project_id
  source_dir         = "./job-code"
  main_file          = "processor.py"
  schedule           = "0 2 * * *" # 2 AM daily
  description        = "Daily data processing job"

  # Job-specific configuration
  job_cpu     = "2000m"
  job_memory  = "2Gi"
  job_timeout = "7200s" # 2 hours

  # Container image (use the built image)
  job_image = module.daily_data_processor_image.image_digest

  environment_variables = {
    ENV       = "production"
    LOG_LEVEL = "INFO"
  }

  secrets = [
    {
      env_var_name = "DATABASE_URL"
      secret_id    = "database-connection-string"
      version      = "latest"
    }
  ]

  # Alerting is enabled by default
  slack_channel        = var.slack_channel
  slack_mention_users  = ["@oncall"]  # Optional: mention specific users/groups

  # Optional: Use different project for alerting resources
  alert_project_id = var.alert_project_id
}

# Output the job details
output "job_info" {
  description = "Information about the deployed job"
  value = {
    job_name              = module.daily_data_processor.resource_name
    service_account_email = module.daily_data_processor.service_account_email
    scheduler_job_name    = module.daily_data_processor.scheduler_job_name
    execution_type        = module.daily_data_processor.execution_type
  }
}

# Output the image details
output "image_info" {
  description = "Information about the built container image"
  value = {
    image_digest = module.daily_data_processor_image.image_digest
    image_uri    = module.daily_data_processor_image.image_uri
    image_tag    = module.daily_data_processor_image.image_tag
  }
}

# Output alerting information
output "alerting_info" {
  description = "Information about the alerting setup"
  value = {
    monitoring_notification_channel_name = module.daily_data_processor.monitoring_notification_channel_name
    alert_policy_names                   = module.daily_data_processor.alert_policy_names
  }
}
