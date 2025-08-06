# Input variables for the GitHub CI Bootstrap module

variable "google_project_name" {
  description = "The Google Cloud project name where CI resources will be created"
  type        = string
}

variable "project_name" {
  description = "Short name for the project (used in resource names)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "project_display_name" {
  description = "Human-readable display name for the project (used in resource descriptions)"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in the format 'org/repo' (e.g., 'Khan/culture-cron')"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "GitHub repository must be in the format 'org/repo'."
  }
}

variable "terraform_state_bucket" {
  description = "GCS bucket name for storing Terraform state"
  type        = string
}

variable "required_services" {
  description = "List of GCP services that the CI service account needs access to"
  type        = list(string)
  default     = ["cloudfunctions", "storage", "pubsub", "scheduler"]
  validation {
    condition = alltrue([
      for service in var.required_services : contains([
        "cloudfunctions",
        "storage", 
        "pubsub",
        "scheduler"
      ], service)
    ])
    error_message = "Required services must be one of: cloudfunctions, storage, pubsub, scheduler."
  }
}

variable "secrets_project_id" {
  description = "The Google Cloud project ID where secrets are stored (optional)"
  type        = string
  default     = null
}

variable "secret_ids" {
  description = "List of secret IDs that the service account needs access to"
  type        = list(string)
  default     = []
} 