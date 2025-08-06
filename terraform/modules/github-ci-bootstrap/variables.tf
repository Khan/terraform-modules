# Input variables for the GitHub CI Bootstrap module

variable "service_name" {
  description = "Name of the Terraform setup/environment for CI operations (e.g., 'culture-cron-prod', 'webapp-staging')"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "Service name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "github_repository" {
  description = "GitHub repository in the format 'org/repo' (e.g., 'Khan/culture-cron')"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "GitHub repository must be in the format 'org/repo'."
  }
}

variable "target_projects" {
  description = "Map of GCP projects this service account needs access to"
  type = map(object({
    project_id        = string
    required_services = list(string)
  }))
  default = {}
  validation {
    condition = alltrue(flatten([
      for proj_key, proj in var.target_projects : [
        for service in proj.required_services : contains([
          "cloudfunctions",
          "storage",
          "pubsub",
          "scheduler"
        ], service)
      ]
    ]))
    error_message = "Required services must be one of: cloudfunctions, storage, pubsub, scheduler."
  }
}

variable "terraform_state_bucket" {
  description = "GCS bucket name for storing Terraform state (defaults to terraform-{org}-{repo}-{service})"
  type        = string
  default     = null
}

variable "secrets_project_id" {
  description = "The Google Cloud project ID where secrets are stored (defaults to khan-academy)"
  type        = string
  default     = "khan-academy"
}

variable "secret_ids" {
  description = "List of secret IDs that the service account needs access to"
  type        = list(string)
  default     = []
} 