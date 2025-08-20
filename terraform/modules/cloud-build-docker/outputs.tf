# Outputs for the Cloud Build Docker module

output "image_digest" {
  description = "Full image digest (e.g., gcr.io/project/image@sha256:abc123...)"
  value       = local.image_digest
}

output "image_uri" {
  description = "Image URI without tag (e.g., gcr.io/project/image)"
  value       = local.image_uri
}

output "image_tag" {
  description = "Image URI with tag (e.g., gcr.io/project/image:latest)"
  value       = local.image_tag
}

output "image_name" {
  description = "Name of the built image"
  value       = var.image_name
}

output "image_tag_suffix" {
  description = "Tag suffix used for the image"
  value       = var.image_tag_suffix
}

output "project_id" {
  description = "Project ID where the image was built"
  value       = var.project_id
}
