# Simple Build Example

This example demonstrates the basic usage of the Cloud Build Docker module to build a simple web application using Artifact Registry.

## What this example creates

- A Docker image built using Google Cloud Build
- Image stored in Artifact Registry
- A simple nginx-based web application
- Image digest output for use in other Terraform resources

## Prerequisites

Before running this example, ensure you have:

1. An Artifact Registry Docker repository created:
   ```bash
   gcloud artifacts repositories create docker-images \
     --repository-format=docker \
     --location=us-central1 \
     --project=your-gcp-project
   ```

## Usage

1. Set your project variables:

   ```bash
   export TF_VAR_project_id="your-gcp-project"
   ```

2. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. The module will build the Docker image and output the digest.

## Configuration

The example uses minimal configuration:

```hcl
module "web_app_image" {
  source = "../.."

  image_name       = "simple-web-app"
  context_path     = "./app"
  project_id       = var.project_id
  image_tag_suffix = "latest"
  region           = var.region
  repository       = "docker-images"  # Artifact Registry repository (must exist)
}
```

## Application Structure

```
app/
├── Dockerfile     # Multi-stage nginx build
├── index.html     # Simple web page
└── nginx.conf     # Nginx configuration
```

## Outputs

After running `terraform apply`, you'll get:

```hcl
image_info = {
  image_digest = "us-central1-docker.pkg.dev/your-project/docker-images/simple-web-app@sha256:abc123..."
  image_uri    = "us-central1-docker.pkg.dev/your-project/docker-images/simple-web-app"
  image_tag    = "us-central1-docker.pkg.dev/your-project/docker-images/simple-web-app:latest"
}
```

## Next Steps

You can use the `image_digest` output to deploy the image to:

- Cloud Run
- GKE
- Compute Engine
- Or any other container platform
