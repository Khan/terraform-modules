# Variables for the Cloud Build Docker module

variable "image_name" {
  description = "Name of the Docker image to build"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.image_name))
    error_message = "Image name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number."
  }
}

variable "context_path" {
  description = "Path to the build context directory (relative to terraform root)"
  type        = string
}

variable "dockerfile_path" {
  description = "Path to the Dockerfile (relative to context_path, or absolute path)"
  type        = string
  default     = "Dockerfile"
}

variable "project_id" {
  description = "The GCP project ID where the image will be built and stored"
  type        = string
}

variable "image_tag_suffix" {
  description = "Tag suffix for the image (e.g., 'latest', 'v1.0.0', branch name)"
  type        = string
  validation {
    condition     = length(var.image_tag_suffix) > 0
    error_message = "Image tag suffix cannot be empty."
  }
}

variable "base_digest" {
  description = "Base image digest for build args (defaults to 'latest')"
  type        = string
  default     = "latest"
}

variable "region" {
  description = "The GCP region where Cloud Build jobs will run and where Artifact Registry is located"
  type        = string
  default     = "us-central1"
}

variable "repository" {
  description = "Artifact Registry repository name (must already exist)"
  type        = string
  default     = "docker-images"
}
