# Variables for the Scheduled Cloud Function module
# This module creates a complete scheduled Cloud Function setup with:
# - Cloud Function (2nd gen)
# - Cloud Scheduler job
# - PubSub topic for triggering
# - Service account with appropriate permissions
# - Storage bucket for function code
# - Secret Manager IAM bindings

variable "function_name" {
  description = "Name of the Cloud Function and related resources (will be used as prefix)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.function_name))
    error_message = "Function name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number."
  }
}

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "secrets_project_id" {
  description = "The GCP project ID where secrets are stored (can be same as project_id)"
  type        = string
}

# Source code configuration
variable "source_dir" {
  description = "Path to the directory containing the function source code (relative to terraform root)"
  type        = string
}

variable "entry_point" {
  description = "Name of the function to execute (e.g., 'main')"
  type        = string
  default     = "main"
}

variable "runtime" {
  description = "Runtime for the Cloud Function"
  type        = string
  default     = "python311"
}

variable "main_file" {
  description = "Name of the main Python file (for GOOGLE_FUNCTION_SOURCE env var)"
  type        = string
}

# Scheduling configuration
variable "schedule" {
  description = "Cron expression for the schedule (e.g., '0 9 * * 1-5' for 9 AM weekdays)"
  type        = string
}

variable "time_zone" {
  description = "Time zone for the schedule"
  type        = string
  default     = "UTC"
}

variable "description" {
  description = "Description for the Cloud Function and scheduler job"
  type        = string
}

# Function configuration
variable "memory" {
  description = "Memory allocation for the Cloud Function"
  type        = string
  default     = "2048M"
}

variable "timeout_seconds" {
  description = "Timeout in seconds for the Cloud Function"
  type        = number
  default     = 60
}

variable "max_instance_count" {
  description = "Maximum number of function instances"
  type        = number
  default     = 1
}

variable "min_instance_count" {
  description = "Minimum number of function instances"
  type        = number
  default     = 1
}

# Environment variables
variable "environment_variables" {
  description = "Environment variables for the Cloud Function"
  type        = map(string)
  default     = {}
}

# Secret configuration
variable "secrets" {
  description = "List of secrets to access from Secret Manager"
  type = list(object({
    env_var_name = string # Environment variable name in the function
    secret_id    = string # Secret ID in Secret Manager
    version      = string # Secret version (default: "latest")
  }))
  default = []
}

# Build configuration
variable "excludes" {
  description = "List of files/directories to exclude from the function archive"
  type        = list(string)
  default     = ["terraform", ".github", ".git", ".venv", ".gcloud", "Makefile", "README.md", "LICENSE", ".gitignore"]
}

variable "build_environment_variables" {
  description = "Environment variables for the build process"
  type        = map(string)
  default     = {}
}

# Dependencies
variable "requirements_file" {
  description = "Path to requirements.txt file (relative to source_dir)"
  type        = string
  default     = "requirements.txt"
}
