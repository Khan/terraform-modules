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
