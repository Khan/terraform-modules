# Cloud Build Docker Module
# This module provides a reusable way to build Docker images using Cloud Build
# with branch-based caching and digest tracking for Terraform.

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.0.0"
    }
  }
}

# External data source to build images and return their digests
data "external" "image_build" {
  program = ["${path.module}/build_image.py"]

  query = {
    image_name       = var.image_name
    context          = var.context_path
    dockerfile       = var.dockerfile_path
    project_id       = var.project_id
    image_tag_suffix = var.image_tag_suffix
    base_digest      = var.base_digest
    region           = var.region
    repository       = var.repository
  }

  # Trigger rebuild when any of these change
  depends_on = [
    var.context_path,
    var.dockerfile_path,
    var.image_tag_suffix,
    var.project_id
  ]
}

# Local values for easy access
locals {
  image_digest = data.external.image_build.result.digest
  image_uri    = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository}/${var.image_name}"
  image_tag    = "${local.image_uri}:${var.image_tag_suffix}"
}
