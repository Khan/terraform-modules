# Input variables for the GitHub Terraform CI Bootstrap module

variable "service_name" {
  description = "User-defined unique identifier for this Terraform configuration and environment. You choose this name to distinguish different Terraform setups (e.g., 'culture-cron-prod', 'webapp-staging', 'api-dev'). This creates isolated CI infrastructure including service accounts, state buckets, and IAM providers for each setup. One repo may have multiple service_names for different environments or configurations."
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
  description = "Map of GCP projects where this Terraform configuration will deploy resources. Keys are project IDs."
  type = map(object({
    required_services = list(string)
  }))
  default = {}
  validation {
    condition = alltrue(flatten([
      for project_id, config in var.target_projects : [
        for service in config.required_services : contains([
          "cloudfunctions",
          "storage",
          "pubsub",
          "scheduler",
          "run",
          "cloudbuild",
          "artifactregistry",
          "secretmanager",
          "logging",
          "monitoring"
        ], service)
      ]
    ]))
    error_message = "Required services must be one of: cloudfunctions, storage, pubsub, scheduler, run, cloudbuild, artifactregistry, secretmanager, logging, monitoring."
  }
}


variable "write_branch_patterns" {
  description = "List of branch patterns that are allowed to use the read/write service account (defaults to main and master)"
  type        = list(string)
  default     = ["main", "master"]
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
  description = "List of secret IDs that the Terraform configuration needs access to"
  type        = list(string)
  default     = []
} 