# Simple example of using the Cloud Build Docker module
# This shows the minimum configuration needed to build a Docker image

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Build a simple web application image
module "web_app_image" {
  source = "../.."

  image_name       = "simple-web-app"
  context_path     = "./app"
  project_id       = var.project_id
  image_tag_suffix = "latest"
  region           = var.region
  repository       = "docker-images"  # Artifact Registry repository (must exist)
}

# Output the built image information
output "image_info" {
  description = "Information about the built Docker image"
  value = {
    image_digest = module.web_app_image.image_digest
    image_uri    = module.web_app_image.image_uri
    image_tag    = module.web_app_image.image_tag
  }
}
