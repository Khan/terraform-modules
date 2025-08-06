# GitHub CI Bootstrap Module

This Terraform module creates the necessary infrastructure for GitHub Actions to manage GCP resources using Workload Identity Federation. It follows the principle of least privilege and only grants permissions needed for the specified services.

## Features

- **Service Account Creation**: Creates a dedicated service account for GitHub Actions
- **Workload Identity Federation**: Uses modern, keyless authentication
- **Least Privilege**: Only grants permissions for specified GCP services  
- **Secret Management**: Optional access to Google Secret Manager secrets
- **Configurable Services**: Enable only the GCP services you need
- **Repository Scoped**: Restricts access to a specific GitHub repository

## Usage

```hcl
module "github_ci_bootstrap" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=main"

  # Project configuration
  project_id           = "my-gcp-project"
  project_name         = "my-project"
  project_display_name = "My Project"
  
  # GitHub configuration
  github_repository = "myorg/my-repo"
  
  # Terraform state
  terraform_state_bucket = "my-terraform-state-bucket"
  
  # Services (optional - defaults to all)
  required_services = ["cloudfunctions", "storage", "pubsub", "scheduler"]
  
  # Secrets (optional)
  secrets_project_id = "my-secrets-project"
  secret_ids = [
    "projects/my-secrets-project/secrets/my-secret",
    "projects/my-secrets-project/secrets/another-secret"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_id` | The Google Cloud project ID where CI resources will be created | `string` | n/a | yes |
| `project_name` | Short name for the project (used in resource names) | `string` | n/a | yes |
| `project_display_name` | Human-readable display name for the project | `string` | n/a | yes |
| `github_repository` | GitHub repository in format 'org/repo' | `string` | n/a | yes |
| `terraform_state_bucket` | GCS bucket name for storing Terraform state | `string` | n/a | yes |
| `required_services` | List of GCP services needing access | `list(string)` | `["cloudfunctions", "storage", "pubsub", "scheduler"]` | no |
| `secrets_project_id` | Project ID where secrets are stored | `string` | `null` | no |
| `secret_ids` | List of secret IDs for access | `list(string)` | `[]` | no |

### Available Services

- `cloudfunctions` - Enables Cloud Functions deployment and management
- `storage` - Enables Cloud Storage bucket management  
- `pubsub` - Enables Pub/Sub topic and subscription management
- `scheduler` - Enables Cloud Scheduler job management

## Outputs

| Name | Description |
|------|-------------|
| `service_account_email` | Email of the created service account |
| `workload_identity_provider` | Full resource name of the Workload Identity provider |
| `project_id` | The project ID where resources were created |

## GitHub Actions Configuration

After applying this module, configure your GitHub Actions workflow:

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
- **Least Privilege**: Only grants permissions for enabled services
- **Secret Scoping**: Fine-grained access to specific secrets only

## Examples

### Minimal Configuration
```hcl
module "ci_bootstrap" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  project_id             = "my-project"
  project_name           = "my-app"
  project_display_name   = "My Application"
  github_repository      = "myorg/my-app"
  terraform_state_bucket = "my-terraform-state"
}
```

### With Secrets Access
```hcl
module "ci_bootstrap" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  project_id             = "my-project"
  project_name           = "my-app"
  project_display_name   = "My Application"
  github_repository      = "myorg/my-app"
  terraform_state_bucket = "my-terraform-state"
  
  secrets_project_id = "my-secrets-project"
  secret_ids = [
    "projects/my-secrets-project/secrets/api-token"
  ]
}
```

### Storage-Only Access
```hcl
module "ci_bootstrap" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  project_id             = "my-project"
  project_name           = "static-site"
  project_display_name   = "Static Site"
  github_repository      = "myorg/static-site"
  terraform_state_bucket = "my-terraform-state"
  
  required_services = ["storage"]
}
``` 