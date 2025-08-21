# Simple Build Example

This example demonstrates the basic usage of the Cloud Build Docker module to build a simple web application.

## What this example creates

- A Docker image built using Google Cloud Build
- A simple nginx-based web application
- Image digest output for use in other Terraform resources

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
  image_digest = "gcr.io/your-project/simple-web-app@sha256:abc123..."
  image_uri    = "gcr.io/your-project/simple-web-app"
  image_tag    = "gcr.io/your-project/simple-web-app:latest"
}
```

## Next Steps

You can use the `image_digest` output to deploy the image to:
- Cloud Run
- GKE
- Compute Engine
- Or any other container platform
