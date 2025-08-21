variable "project_id" {
  description = "The GCP project ID where the image will be built"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}
