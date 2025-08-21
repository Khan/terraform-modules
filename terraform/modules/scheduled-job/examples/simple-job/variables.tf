variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "secrets_project_id" {
  description = "The GCP project ID where secrets are stored (can be same as project_id)"
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "slack_channel" {
  description = "Slack channel to send notifications to (e.g., '#my-team-channel')"
  type        = string
}

variable "alert_project_id" {
  description = "GCP project ID where monitoring and alerting resources will be created (optional, defaults to project_id)"
  type        = string
  default     = null
}
