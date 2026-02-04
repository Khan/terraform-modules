# terraform-cloud-build-docker-module

A reusable Terraform module for building Docker images using Google Cloud Build with Artifact Registry, branch-based caching, and digest tracking.

## Features

- **Cloud Build Integration**: Uses Google Cloud Build for reliable, scalable Docker image building
- **Branch-based Caching**: Optimizes build times by caching layers based on branch names
- **Cache Fallback**: Automatically falls back to "latest" tag if the specified cache tag doesn't exist, ensuring we always have some level of caching
- **Digest Tracking**: Returns full image digests for precise versioning in Terraform
- **Flexible Dockerfile Support**: Supports custom Dockerfile names and locations
- **Build Arguments**: Supports custom build arguments and base image digests
- **Custom Configurations**: Allows custom Cloud Build configurations

## Quick Start

```hcl
module "my_app_image" {
  source = "git::https://github.com/Khan/terraform-cloud-build-docker-module.git?ref=v1.0.0"

  image_name       = "my-app"
  context_path     = "./app"
  dockerfile_path  = "Dockerfile"
  project_id       = "my-gcp-project"
  image_tag_suffix = "latest"
  region           = "us-central1"
  repository       = "docker-images"  # Artifact Registry repository (must exist)
}

# Use the built image digest
resource "google_cloud_run_v2_service" "my_service" {
  # ... other config
  template {
    template {
      containers {
        image = module.my_app_image.image_digest
      }
    }
  }
}
```

## Examples

Complete working examples are available in the [`examples/`](./examples/) directory:

- **[`simple-build/`](./examples/simple-build/)** - Basic Docker image build with minimal configuration
- **[`custom-dockerfile/`](./examples/custom-dockerfile/)** - Using custom Dockerfile names and locations
- **[`build-args/`](./examples/build-args/)** - Using build arguments and base image digests

## Usage Examples

### Basic Image Build

```hcl
module "web_app" {
  source = "git::https://github.com/Khan/terraform-cloud-build-docker-module.git?ref=v1.0.0"

  image_name       = "web-app"
  context_path     = "./web"
  project_id       = var.project_id
  image_tag_suffix = "v1.0.0"
}
```

### Custom Dockerfile Location

```hcl
module "api_service" {
  source = "git::https://github.com/Khan/terraform-cloud-build-docker-module.git?ref=v1.0.0"

  image_name       = "api-service"
  context_path     = "./api"
  dockerfile_path  = "dockerfiles/production.Dockerfile"  # Relative to context_path
  project_id       = var.project_id
  image_tag_suffix = "production"
}
```

**Note**: The `dockerfile_path` is relative to the `context_path`. In this example, the Dockerfile would be located at `./api/dockerfiles/production.Dockerfile`.

### With Build Arguments

```hcl
module "data_processor" {
  source = "git::https://github.com/Khan/terraform-cloud-build-docker-module.git?ref=v1.0.0"

  image_name       = "data-processor"
  context_path     = "./processor"
  project_id       = var.project_id
  image_tag_suffix = "latest"
  
  build_args = {
    NODE_ENV = "production"
    VERSION  = "1.2.3"
  }
}
```

### With Base Image Digest

```hcl
module "secure_app" {
  source = "git::https://github.com/Khan/terraform-cloud-build-docker-module.git?ref=v1.0.0"

  image_name       = "secure-app"
  context_path     = "./app"
  project_id       = var.project_id
  image_tag_suffix = "latest"
  base_digest      = "gcr.io/my-project/base-image@sha256:abc123..."
}
```

## Requirements & Inputs

### Required

- `image_name` - Name of the Docker image to build
- `context_path` - Path to the build context directory
- `project_id` - GCP project ID where the image will be built
- `image_tag_suffix` - Tag suffix for the image (e.g., 'latest', 'v1.0.0')

### Optional (with defaults)

- `dockerfile_path` - Path to the Dockerfile relative to context_path ("Dockerfile")
- `base_digest` - Base image digest for build args ("latest")
- `region` - GCP region for Cloud Build and Artifact Registry ("us-central1")
- `repository` - Artifact Registry repository name ("docker-images")

## Outputs

- `image_digest` - Full image digest (e.g., us-central1-docker.pkg.dev/project/repo/image@sha256:abc123...)
- `image_uri` - Image URI without tag (e.g., us-central1-docker.pkg.dev/project/repo/image)
- `image_tag` - Image URI with tag (e.g., us-central1-docker.pkg.dev/project/repo/image:latest)
- `image_name` - Name of the built image
- `image_tag_suffix` - Tag suffix used for the image
- `project_id` - Project ID where the image was built

## How It Works

### Build Process

1. **Context Preparation**: The module prepares the build context and handles Dockerfile symlinks if needed
2. **Cache Tag Resolution**: Determines the effective cache tag by checking if the specified tag exists, falling back to "latest" if not
3. **Cloud Build Submission**: Submits the build to Google Cloud Build with appropriate substitutions
4. **Caching**: Uses the effective cache tag for layer caching to optimize build times
5. **Digest Retrieval**: Queries the built image to get its full digest
6. **Output**: Returns the digest for use in other Terraform resources

### Caching Strategy

- **Branch-based**: Uses the `image_tag_suffix` as a cache tag
- **Fallback to Latest**: If the specified cache tag doesn't exist, falls back to using "latest" as the cache tag, ensuring we always have some level of caching
- **Layer Reuse**: Subsequent builds reuse cached layers when possible
- **Cache Invalidation**: Cache is automatically invalidated when Dockerfile or context changes

### Dockerfile Support

The module supports various Dockerfile configurations:

- **Standard**: `Dockerfile` in the context root (default)
- **Custom names**: Use `dockerfile_path = "production.Dockerfile"` for files like `production.Dockerfile`
- **Subdirectories**: Use `dockerfile_path = "dockerfiles/app.Dockerfile"` for files in subdirectories
- **Automatic symlinking**: The module creates temporary symlinks to make custom Dockerfile names work with Cloud Build

**Example structure:**

```
./app/
├── Dockerfile                    # Default: dockerfile_path = "Dockerfile"
├── production.Dockerfile         # Custom: dockerfile_path = "production.Dockerfile"
└── dockerfiles/
    └── app.Dockerfile           # Subdirectory: dockerfile_path = "dockerfiles/app.Dockerfile"
```

**Note**: The `dockerfile_path` is always relative to the `context_path`.

## Repository Structure

```
your-app-repo/
├── terraform/
│   └── main.tf                    # Uses module
├── app/
│   ├── Dockerfile                 # Standard Dockerfile
│   ├── src/
│   └── package.json
├── api/
│   ├── dockerfiles/
│   │   └── production.Dockerfile  # Custom Dockerfile
│   └── src/
└── README.md
```

## Prerequisites

### GCP Setup

- Google Cloud Build API enabled
- Artifact Registry API enabled
- An Artifact Registry Docker repository created in the target region (e.g., `gcloud artifacts repositories create docker-images --repository-format=docker --location=us-central1`)
- Appropriate IAM permissions for Cloud Build and Artifact Registry

### Local Setup

- `gcloud` CLI installed and authenticated
- Terraform >= 1.3.0

### GCS Buckets

The module expects the required GCS bucket to exist:

- `gs://{project_id}-cloudbuild-ci` - For build staging and logs

**Note**: Cloud Build will automatically create this bucket if it doesn't exist, but for production use, you may want to create it explicitly with proper IAM permissions.

## Common Patterns

### Version Tagging

```hcl
# Use semantic versioning
image_tag_suffix = "v1.2.3"

# Use git commit hash
image_tag_suffix = "sha-${substr(sha256(file("${path.module}/app/Dockerfile")), 0, 8)}"

# Use branch name
image_tag_suffix = "branch-${replace(var.git_branch, "/", "-")}"
```

### Multi-stage Builds

The module works seamlessly with multi-stage Dockerfiles:

```dockerfile
# Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
CMD ["npm", "start"]
```

### Integration with Cloud Run

```hcl
module "app_image" {
  source = "git::https://github.com/Khan/terraform-cloud-build-docker-module.git?ref=v1.0.0"
  
  image_name       = "my-app"
  context_path     = "./app"
  project_id       = var.project_id
  image_tag_suffix = "latest"
}

resource "google_cloud_run_v2_service" "app" {
  name     = "my-app"
  location = var.region

  template {
    template {
      containers {
        image = module.app_image.image_digest
      }
    }
  }
}
```

## Troubleshooting

### Build Failures

- Check Cloud Build logs in the GCS bucket
- Verify Dockerfile syntax and context
- Ensure all required files are in the build context

### Permission Issues

- Verify Cloud Build service account has necessary permissions
- Check Artifact Registry access (Cloud Build service account needs `roles/artifactregistry.writer`)
- Ensure GCS buckets exist and are accessible
- Ensure the Artifact Registry repository exists in the specified region

### Cache Issues

- Clear cache by using a unique `image_tag_suffix`
- Check if base images are accessible
- Verify network connectivity during builds
- **Cache Fallback**: If you see "falling back to 'latest'" in logs, the specified cache tag doesn't exist and the module is using "latest" instead
