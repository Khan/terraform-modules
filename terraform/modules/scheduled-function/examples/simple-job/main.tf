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

# Simple daily job example
module "daily_data_processor" {
  # When used from another repository, this would be:
  # source = "git::https://github.com/Khan/terraform-scheduled-function-module.git?ref=v1.0.0"
  source = "../.."

  function_name      = "daily-data-processor"
  execution_type     = "job"
  project_id         = var.project_id
  secrets_project_id = var.secrets_project_id
  source_dir         = "./job-code"
  main_file          = "processor.py"
  schedule           = "0 2 * * *" # 2 AM daily
  description        = "Daily data processing job"

  # Job-specific configuration
  job_cpu    = "2000m"
  job_memory = "2Gi"
  job_timeout = "7200s" # 2 hours
  
  # Container image (build and push separately)
  job_image = "gcr.io/${var.project_id}/daily-data-processor:latest"

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
}

# Output the job details
output "job_info" {
  description = "Information about the deployed job"
  value = {
    job_name              = module.daily_data_processor.job_name
    service_account_email = module.daily_data_processor.service_account_email
    scheduler_job_name    = module.daily_data_processor.scheduler_job_name
    execution_type        = module.daily_data_processor.execution_type
  }
}
