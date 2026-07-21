# Variables for the Scheduled Cloud Function/Job module
# This module creates a complete scheduled setup with:
# - Cloud Function (2nd gen) OR Cloud Run Job
# - Cloud Scheduler job
# - PubSub topic for triggering
# - Service account with appropriate permissions
# - Storage bucket for function/job code
# - Secret Manager IAM bindings

variable "execution_type" {
  description = "Type of execution: 'function' for Cloud Functions or 'job' for Cloud Run Jobs"
  type        = string
  default     = "function"
  validation {
    condition     = contains(["function", "job"], var.execution_type)
    error_message = "Execution type must be either 'function' or 'job'."
  }
}

variable "job_name" {
  description = "Name of the Cloud Function/Job and related resources (will be used as prefix)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.job_name))
    error_message = "Job name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number."
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
  description = "Path to the directory containing the function source code (relative to terraform root, required for Cloud Functions)"
  type        = string
  default     = null
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
  description = "Name of the main Python file (for GOOGLE_FUNCTION_SOURCE env var, required for Cloud Functions)"
  type        = string
  default     = null
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

variable "retries_enabled" {
  description = "Whether the retry policy is set to `RETRY_POLICY_RETRY`"
  type        = bool
  default     = false
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

# Cloud Run Job specific variables
variable "job_cpu" {
  description = "CPU allocation for the Cloud Run Job (e.g., '1000m', '2')"
  type        = string
  default     = "1000m"
}

variable "job_memory" {
  description = "Memory allocation for the Cloud Run Job (e.g., '512Mi', '2Gi')"
  type        = string
  default     = "512Mi"
}

variable "job_timeout" {
  description = "Timeout for the Cloud Run Job (e.g., '3600s', '1h', '2h30m')"
  type        = string
  default     = "3600s"
}

variable "job_parallelism" {
  description = "Number of parallel executions for the Cloud Run Job"
  type        = number
  default     = 1
}

variable "job_task_count" {
  description = "Number of tasks to run for the Cloud Run Job"
  type        = number
  default     = 1
}

variable "job_command" {
  description = "Command to run in the Cloud Run Job container"
  type        = list(string)
  default     = ["python", "main.py"]
}

variable "job_args" {
  description = "Arguments to pass to the command in the Cloud Run Job"
  type        = list(string)
  default     = []
}

variable "job_image" {
  description = "Container image URL for the Cloud Run Job (e.g., 'gcr.io/project-id/job-name:latest')"
  type        = string
  default     = null
}

# Alerting configuration
variable "enable_alerting" {
  description = "Whether to enable alerting for job failures"
  type        = bool
  default     = true
}

variable "notification_channel_ids" {
  description = "Full resource names of pre-created Cloud Monitoring notification channels (projects/PROJECT/notificationChannels/ID) for failure alerts. Strongly preferred over the default: when empty, the module creates a Slack channel itself by reading the alertlib token with a data source, which persists the token value into Terraform state and any saved plan files. Pre-create the channel once per project (e.g. via the console's Slack OAuth flow, which never handles the token in Terraform) and pass its name here."
  type        = list(string)
  default     = []
}

variable "slack_channel" {
  description = "Slack channel to send notifications to (e.g., '#1s-and-0s')"
  type        = string
}

variable "slack_mention_users" {
  description = "List of Slack users or groups to mention in alerts (e.g., ['@user', '@group'])"
  type        = list(string)
  default     = []
}

variable "alert_project_id" {
  description = "GCP project ID where monitoring and alerting resources will be created (defaults to project_id)"
  type        = string
  default     = null
}
