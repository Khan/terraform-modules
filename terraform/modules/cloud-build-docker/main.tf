# Cloud Build Docker Module
# This module provides a reusable way to build Docker images using Cloud Build
# with branch-based caching and digest tracking for Terraform.
#
# NOTE: Uses null_resource instead of data.external to ensure builds ONLY run
# during apply phase, not during plan phase (saves time and money).

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}

# Local values
locals {
  image_uri    = "gcr.io/${var.project_id}/${var.image_name}"
  image_tag    = "${local.image_uri}:${var.image_tag_suffix}"
  digest_file  = "${path.module}/.digests/${var.project_id}_${var.image_name}_${var.image_tag_suffix}.txt"
  digest_dir   = "${path.module}/.digests"
}

# Ensure digest file exists (create placeholder if missing)
# This prevents data source errors on first run
resource "null_resource" "ensure_digest_file" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${local.digest_dir}
      if [ ! -f ${local.digest_file} ]; then
        echo "${local.image_tag}" > ${local.digest_file}
      fi
    EOT
  }
}

# Build image using null_resource (runs ONLY during apply, not plan)
resource "null_resource" "image_build" {
  # Trigger rebuild when these change
  triggers = {
    context_path       = var.context_path
    dockerfile_path    = var.dockerfile_path
    image_tag_suffix   = var.image_tag_suffix
    project_id         = var.project_id
    base_digest        = var.base_digest
    build_trigger_hash = var.build_trigger_hash  # Content-based rebuild trigger
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p ${dirname(local.digest_file)}

      # Run build script and capture digest from JSON output
      DIGEST=$(echo '${jsonencode({
        image_name       = var.image_name
        context          = var.context_path
        dockerfile       = var.dockerfile_path
        project_id       = var.project_id
        image_tag_suffix = var.image_tag_suffix
        base_digest      = var.base_digest
      })}' | python3 ${path.module}/build_image.py | jq -r '.digest')

      # Save digest to file for Terraform to read
      echo "$DIGEST" > ${local.digest_file}
    EOT
  }
}

# Read digest from file
# The ensure_digest_file resource guarantees the file exists before we try to read it
data "local_file" "image_digest" {
  depends_on = [
    null_resource.ensure_digest_file,
    null_resource.image_build
  ]
  filename = local.digest_file
}

# Local value for digest (with fallback to tag on first run)
locals {
  # Use digest if file exists, otherwise use tag (Cloud Run will resolve to digest)
  # This prevents deployment failures on first run while still using immutable references
  image_digest = try(trimspace(data.local_file.image_digest.content), local.image_tag)
}
