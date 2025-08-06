# GitHub Terraform CI Bootstrap Module

This module creates the necessary infrastructure for **GitHub Terraform CI** - managing Terraform infrastructure through GitHub Actions CI/CD pipelines. It provisions service accounts with appropriate GCP permissions and uses Workload Identity Federation for keyless authentication to run `terraform plan` and `terraform apply` operations.

## Purpose

Each module invocation creates a dedicated service account for a complete Terraform configuration managed in CI. This enables:

- **Isolated Terraform CI**: Each Terraform setup gets its own service account and state bucket for CI operations
- **Secure GitHub Actions**: Run `terraform plan` and `terraform apply` in GitHub Actions without storing keys
- **Cross-Project Deployments**: Single service account can manage Terraform resources across multiple GCP projects  
- **Environment Separation**: Separate CI service accounts for prod, staging, dev, etc.

## Features

- **Shared Infrastructure**: Uses a single Workload Identity Pool in khan-internal-services for all GitHub Terraform CI
- **Dedicated Service Accounts**: Creates unique service accounts for each Terraform configuration managed in CI
- **Workload Identity Federation**: Uses modern, keyless authentication for GitHub Actions
- **Cross-Project Support**: Service accounts can deploy Terraform resources across multiple GCP projects
- **Least Privilege**: Only grants permissions for specified GCP services in target projects
- **Terraform State Management**: Automatic permissions for GCS-based Terraform state buckets
- **Secret Management**: Optional access to Google Secret Manager secrets needed by Terraform
- **Configurable Services**: Enable only the GCP services your Terraform configuration manages
- **Repository Scoped**: Restricts access to a specific GitHub repository containing Terraform code

## Architecture

All GitHub Terraform CI infrastructure is centralized in the `khan-internal-services` project:
- **Single Pool**: `khan-internal-services-github-ci` pool shared by all Terraform configurations managed in CI
- **Unique Providers**: Each Terraform configuration gets its own provider within the shared pool  
- **Cross-Project Permissions**: Service accounts get permissions in target projects for Terraform resource management
- **State Bucket Access**: Service accounts get appropriate permissions for Terraform state storage in CI

## Usage

```hcl
# Bootstrap GitHub Terraform CI for the culture-cron production configuration
module "culture_cron_terraform_ci" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  # Terraform configuration managed in CI
  service_name      = "culture-cron-prod"        # Name of this Terraform configuration
  github_repository = "Khan/culture-cron"        # GitHub repo containing the Terraform code
  
  # Target projects where this Terraform configuration deploys resources via CI
  target_projects = {
    prod = {
      project_id        = "khan-academy"
      required_services = ["cloudfunctions", "storage", "pubsub", "scheduler"]
    }
  }
  
  # Terraform state bucket (optional - defaults to terraform-khan-<github_repository>-<service_name>)
  # terraform_state_bucket = "custom-bucket-name"
  
  # Secrets that the Terraform configuration needs access to (optional)
  secret_ids = [
    "projects/khan-academy/secrets/slack-token"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `service_name` | Name of the Terraform setup/environment for CI operations (e.g., 'culture-cron-prod', 'webapp-staging') | `string` | n/a | yes |
| `github_repository` | GitHub repository containing the Terraform configuration in format 'org/repo' | `string` | n/a | yes |
| `target_projects` | Map of GCP projects where this Terraform configuration will deploy resources | `map(object)` | `{}` | no |
| `terraform_state_bucket` | GCS bucket name for storing Terraform state for this configuration | `string` | `terraform-{org}-{repo}-{service}` | no |
| `secrets_project_id` | Project ID where secrets needed by the Terraform configuration are stored | `string` | `"khan-academy"` | no |
| `secret_ids` | List of secret IDs that the Terraform configuration needs access to | `list(string)` | `[]` | no |

### Target Projects Structure

The `target_projects` variable accepts a map where each key is a logical name and the value contains:

```hcl
target_projects = {
  prod = {
    project_id        = "khan-academy"           # GCP project ID
    required_services = ["storage", "pubsub"]    # Services needed in this project
  }
  staging = {
    project_id        = "khan-academy-staging"
    required_services = ["cloudfunctions"]
  }
}
```

### Available Services

These services correspond to GCP resources that your Terraform configuration can deploy and manage:

- `cloudfunctions` - Enables deploying and managing Cloud Functions via Terraform
- `storage` - Enables creating and managing Cloud Storage buckets via Terraform  
- `pubsub` - Enables creating and managing Pub/Sub topics and subscriptions via Terraform
- `scheduler` - Enables creating and managing Cloud Scheduler jobs via Terraform

### Terraform State Bucket Default

If `terraform_state_bucket` is not specified, the module automatically generates a bucket name based on your GitHub repository and service name:

- **Pattern**: `terraform-{org}-{repo}-{service}` (normalized to lowercase)
- **Example**: `Khan/culture-cron` + `culture-cron-prod` → `terraform-khan-culture-cron-culture-cron-prod`
- **Example**: `Khan/webapp` + `webapp-staging` → `terraform-khan-webapp-webapp-staging`
- **Example**: `Khan/Mobile-App` + `mobile-app-prod` → `terraform-khan-mobile-app-mobile-app-prod`

This ensures each Terraform setup gets its own isolated state bucket while maintaining consistent, predictable naming.

## Outputs

| Name | Description |
|------|-------------|
| `service_account_email` | Email of the created service account |
| `workload_identity_provider` | Full resource name of the Workload Identity provider |
| `terraform_state_bucket` | The GCS bucket name used for Terraform state (computed or provided) |
| `service_name` | The Terraform setup name used for this configuration |
| `target_projects` | Map of target projects configured |

## GitHub Actions Configuration

After applying this module, configure your GitHub Actions workflow to manage Terraform in CI:

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ outputs.workload_identity_provider }}
          service_account: ${{ outputs.service_account_email }}
          
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
```

## Security Features

- **No Service Account Keys**: Uses Workload Identity Federation for keyless auth
- **Repository Scoped**: Access restricted to specified GitHub repository
- **Least Privilege**: Only grants permissions for enabled services in target projects
- **Secret Scoping**: Fine-grained access to specific secrets only
- **Centralized Management**: All CI infrastructure managed in khan-internal-services project

## Examples

### Single Project Terraform Configuration (Using Default State Bucket)
```hcl
# CI for culture-cron production Terraform configuration
module "culture_cron_prod_ci" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  service_name      = "culture-cron-prod"
  github_repository = "Khan/culture-cron"
  
  # This Terraform config deploys resources to khan-academy project
  target_projects = {
    prod = {
      project_id        = "khan-academy"
      required_services = ["cloudfunctions", "storage", "pubsub", "scheduler"]
    }
  }
  
  # Terraform state bucket defaults to: terraform-khan-culture-cron-culture-cron-prod
}
```

### Multi-Project Terraform Configuration
```hcl
# CI for webapp staging Terraform configuration that deploys across multiple projects
module "webapp_staging_ci" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  service_name      = "webapp-staging"
  github_repository = "Khan/webapp"
  
  # This Terraform config deploys resources to multiple projects
  target_projects = {
    staging = {
      project_id        = "khan-academy-staging"
      required_services = ["storage", "pubsub"]
    }
    shared = {
      project_id        = "khan-shared-services"
      required_services = ["storage"]
    }
  }
  
  # Terraform state bucket defaults to: terraform-khan-webapp-webapp-staging
}
```

### Terraform Configuration with Secrets Access (Custom State Bucket)
```hcl
# CI for API production Terraform configuration that needs access to secrets
module "api_prod_ci" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  service_name      = "api-prod"
  github_repository = "Khan/api"
  
  target_projects = {
    prod = {
      project_id        = "khan-academy"
      required_services = ["cloudfunctions", "storage"]
    }
  }
  
  # Use custom state bucket instead of default (terraform-khan-api-api-prod)
  terraform_state_bucket = "shared-terraform-state"
  
  # Secrets that the Terraform configuration needs access to
  secret_ids = [
    "projects/khan-academy/secrets/api-key",
    "projects/khan-academy/secrets/database-url"
  ]
}
```

### Terraform Configuration with Storage-Only Access
```hcl
# CI for static site Terraform configuration that only manages storage buckets
module "static_site_prod_ci" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  service_name      = "static-site-prod"
  github_repository = "Khan/static-site"
  
  # This Terraform config only creates storage buckets
  target_projects = {
    prod = {
      project_id        = "khan-academy"
      required_services = ["storage"]
    }
  }
  
  # Terraform state bucket defaults to: terraform-khan-static-site-static-site-prod
}
```
