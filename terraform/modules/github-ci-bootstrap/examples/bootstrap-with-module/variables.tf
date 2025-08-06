# Variables for the bootstrap example

variable "project_id" {
  description = "The Google Cloud project ID where resources will be created"
  type        = string
  default     = "khan-internal-services"
}

variable "region" {
  description = "The Google Cloud region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "secrets_project_id" {
  description = "The Google Cloud project ID where secrets are stored"
  type        = string
  default     = "khan-academy"
} 