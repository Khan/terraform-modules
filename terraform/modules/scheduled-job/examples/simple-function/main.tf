# Simple example of using the scheduled function module
# This shows the minimum configuration needed

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

# Simple daily function example
module "daily_health_check" {
  # When used from another repository, this would be:
  # source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  source = "../.."

  job_name           = "daily-health-check"
  project_id         = var.project_id
  secrets_project_id = var.secrets_project_id
  source_dir         = "./function-code"
  main_file          = "health_check.py"
  schedule           = "0 9 * * *" # 9 AM daily
  description        = "Daily health check function"

  environment_variables = {
    ENV       = "example"
    LOG_LEVEL = "INFO"
  }

  secrets = [
    {
      env_var_name = "API_TOKEN"
      secret_id    = "health-check-api-token"
      version      = "latest"
    }
  ]
}

# Output the function details
output "function_info" {
  description = "Information about the deployed function"
  value = {
    function_name         = module.daily_health_check.function_name
    function_url          = module.daily_health_check.function_url
    service_account_email = module.daily_health_check.service_account_email
    scheduler_job_name    = module.daily_health_check.scheduler_job_name
  }
} 