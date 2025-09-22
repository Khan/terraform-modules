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
- **Dual Service Account Support**: Always creates separate service accounts for write-enabled branches (full access) and read-only access (available to any branch)
- **Workload Identity Federation**: Uses modern, keyless authentication for GitHub Actions
- **Cross-Project Support**: Service accounts can deploy Terraform resources across multiple GCP projects
- **Least Privilege**: Only grants permissions for specified GCP services in target projects
- **Terraform State Management**: Automatic permissions for GCS-based Terraform state buckets
- **Secret Management**: Optional access to Google Secret Manager secrets needed by Terraform
- **Configurable Services**: Enable only the GCP services your Terraform configuration manages
- **Repository Scoped**: Restricts access to a specific GitHub repository containing Terraform code
- **Branch-Based Access Control**: Different permission levels based on GitHub branch patterns

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
  service_name      = "culture-cron-prod"        # YOU choose this name: project + environment
  github_repository = "Khan/culture-cron"        # GitHub repo containing the Terraform code
  
  # Configure which branches can use the write-enabled service account (defaults to main and master)
  write_branch_patterns = ["main", "master"]
  
  # Target projects where this Terraform configuration deploys resources via CI
  target_projects = {
    "khan-academy" = {
      required_services = ["cloudfunctions", "storage", "pubsub", "scheduler", "run", "cloudbuild"]
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

| Name                     | Description                                                                                                                   | Type           | Default                            | Required |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------- | -------------- | ---------------------------------- | :------: |
| `service_name`           | User-defined unique identifier for this Terraform configuration and environment (e.g., 'culture-cron-prod', 'webapp-staging') | `string`       | n/a                                |   yes    |
| `github_repository`      | GitHub repository containing the Terraform configuration in format 'org/repo'                                                 | `string`       | n/a                                |   yes    |
| `target_projects`        | Map of GCP projects where this Terraform configuration will deploy resources. Keys are project IDs.                           | `map(object)`  | `{}`                               |    no    |
| `write_branch_patterns`  | List of branch patterns that are allowed to use the read/write service account (defaults to main and master)                  | `list(string)` | `["main", "master"]`               |    no    |
| `terraform_state_bucket` | GCS bucket name for storing Terraform state for this configuration                                                            | `string`       | `terraform-{org}-{repo}-{service}` |    no    |
| `secrets_project_id`     | Project ID where secrets needed by the Terraform configuration are stored                                                     | `string`       | `"khan-academy"`                   |    no    |
| `secret_ids`             | List of secret IDs that the Terraform configuration needs access to                                                           | `list(string)` | `[]`                               |    no    |

### Target Projects Structure

The `target_projects` variable accepts a map where each key is a GCP project ID:

```hcl
target_projects = {
  "khan-academy" = {
    required_services = ["storage", "pubsub"]    # Services needed in this project
  }
  "khan-academy-staging" = {
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
- `run` - Enables deploying and managing Cloud Run services and jobs via Terraform
- `cloudbuild` - Enables creating and managing Cloud Build triggers and configurations via Terraform

### Terraform State Bucket Default

If `terraform_state_bucket` is not specified, the module automatically generates a bucket name based on your GitHub repository and service name:

- **Pattern**: `terraform-{org}-{repo}-{service}` (normalized for GCS bucket naming rules)
- **Normalization**: Converted to lowercase, underscores replaced with hyphens
- **Example**: `Khan/culture-cron` + `culture-cron-prod` → `terraform-khan-culture-cron-culture-cron-prod`
- **Example**: `Khan/webapp` + `webapp-staging` → `terraform-khan-webapp-webapp-staging`
- **Example**: `Khan/Mobile_App` + `mobile_app_prod` → `terraform-khan-mobile-app-mobile-app-prod`

This ensures each Terraform setup gets its own isolated state bucket while maintaining consistent, predictable naming that complies with GCS bucket naming requirements.

### Dual Service Account Configuration

The module always creates two service accounts with different permission levels:

#### Write-Enabled Branch Service Account (Full Access)

- **Service Account Name**: `{service_name}-ci`
- **Permissions**: Full admin permissions for all specified services
- **Access**: Can create, modify, and delete resources
- **Branch Restriction**: Only works on branches specified in `write_branch_patterns` (defaults to `main` and `master`)
- **Use Case**: Production deployments and infrastructure changes

#### Read-Only Service Account (Read-Only + Cloud Build)

- **Service Account Name**: `{service_name}-ci-pr`
- **Permissions**: Read-only permissions for most services, full access to Cloud Build
- **Access**: Can read resources and run builds, but cannot modify infrastructure
- **Branch Restriction**: Works on any branch in the repository (safe to use anywhere)
- **Use Case**: PR validation, testing, and plan operations
- **Notw**: The one read/write role this service account has is for cloud build. As long as docker images are being referenced with image digests, this cannot affect prod. If tags are used, PR branches can push images to those tags and affect prod deplpoyments.

#### Permission Differences

| Service         | Write-Enabled Branches            | Read-Only Service Account            |
| --------------- | --------------------------------- | ------------------------------------ |
| Cloud Functions | `roles/cloudfunctions.admin`      | `roles/cloudfunctions.viewer`        |
| Storage         | `roles/storage.admin`             | `roles/storage.objectViewer`         |
| Pub/Sub         | `roles/pubsub.admin`              | `roles/pubsub.viewer`                |
| Scheduler       | `roles/cloudscheduler.admin`      | `roles/cloudscheduler.viewer`        |
| Cloud Run       | `roles/run.admin`                 | `roles/run.viewer`                   |
| Cloud Build     | `roles/cloudbuild.builds.builder` | `roles/cloudbuild.builds.builder`    |
| Secret Manager  | `roles/secretmanager.admin`       | `roles/secretmanager.secretAccessor` |
| Terraform State | `roles/storage.objectAdmin`       | `roles/storage.objectViewer`         |

#### Branch Pattern Configuration

The `write_branch_patterns` variable accepts exact branch names:

- `main` - Matches the main branch
- `master` - Matches the master branch
- `production` - Matches a production branch
- `staging` - Matches a staging branch

**Note**: The read-only service account can be used by any branch in the repository since it's inherently safe (cannot make infrastructure changes). Only branches specified in `write_branch_patterns` can use the write-enabled service account for deployments.

### Service Name Guidelines

The `service_name` is a **user-defined identifier** that you choose yourself to distinguish different Terraform configurations managed in CI. This is not something you need to look up - you get to assign it based on your own naming conventions.

#### How to Choose a Service Name

**You should choose a name that clearly identifies:**

1. **What service/application** this Terraform configuration manages
2. **Which environment** (prod, staging, dev, etc.)
3. **What scope** (if you have multiple Terraform configurations per service)

#### Recommended Patterns

- **Basic**: `{service}-{environment}` (e.g., `culture-cron-prod`, `webapp-staging`)
- **With scope**: `{service}-{scope}-{environment}` (e.g., `webapp-frontend-prod`, `webapp-backend-staging`)
- **Shared resources**: `{purpose}-{environment}` (e.g., `shared-infra-prod`, `monitoring-dev`)

#### Examples by Use Case

| Scenario                     | Service Name                                     | What It Represents                                  |
| ---------------------------- | ------------------------------------------------ | --------------------------------------------------- |
| Culture Cron production      | `culture-cron-prod`                              | Production deployment of Culture Cron service       |
| Webapp staging environment   | `webapp-staging`                                 | Staging environment for the main webapp             |
| API development environment  | `api-dev`                                        | Development environment for API service             |
| Shared infrastructure        | `shared-infra-prod`                              | Production shared infrastructure (networking, etc.) |
| Multiple configs per service | `webapp-frontend-prod`<br/>`webapp-backend-prod` | Separate Terraform configs for frontend and backend |

#### Technical Requirements

- **Characters**: Lowercase letters, numbers, and hyphens only (no underscores)
- **Uniqueness**: Must be unique across all your Terraform CI configurations
- **Purpose**: Creates isolated CI infrastructure for each configuration
- **Usage**: Used to generate service account names, state bucket names, and provider IDs

#### Multi-Configuration Repositories

A single GitHub repository can have multiple `service_name` values for different purposes:

- Different environments (`myapp-prod`, `myapp-staging`, `myapp-dev`)
- Different components (`myapp-frontend-prod`, `myapp-backend-prod`)
- Different deployment scopes (`myapp-us-prod`, `myapp-eu-prod`)

Each `service_name` gets its own isolated:

- Service account (`{service_name}-ci`)
- Terraform state bucket (`terraform-{org}-{repo}-{service_name}`)
- Workload Identity provider (`{service_name}-provider`)

**Note**: GitHub repository names may contain underscores, which will be automatically converted to hyphens in generated bucket names to comply with GCS naming requirements.

## Outputs

| Name                            | Description                                                                               |
| ------------------------------- | ----------------------------------------------------------------------------------------- |
| `service_account_email_rw`      | Email of the created service account (write-enabled branches)                             |
| `service_account_email_ro`      | Email of the created service account (read-only, available to any branch)                 |
| `workload_identity_provider_rw` | Full resource name of the Workload Identity provider (write-enabled branches)             |
| `workload_identity_provider_ro` | Full resource name of the Workload Identity provider (read-only, available to any branch) |
| `terraform_state_bucket`        | The GCS bucket name used for Terraform state (computed or provided)                       |
| `service_name`                  | The unique identifier for this Terraform configuration and environment                    |
| `target_projects`               | Map of target projects configured                                                         |
| `write_branch_patterns`         | List of branch patterns that are allowed to use the read/write service account            |

## GitHub Actions Configuration

After applying this module, configure your GitHub Actions workflow to manage Terraform in CI. The module creates two service accounts, so you need to conditionally use different service accounts based on the branch. Note, in these examples the `outputs.xyz` vars should be replaced directly with the output values:

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Authenticate to Google Cloud (Write-Enabled Branches)
        if: contains(fromJSON('["refs/heads/main", "refs/heads/master"]'), github.ref)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ outputs.workload_identity_provider_rw }}
          service_account: ${{ outputs.service_account_email_rw }}
          
      - name: Authenticate to Google Cloud (Read-Only)
        if: !contains(fromJSON('["refs/heads/main", "refs/heads/master"]'), github.ref)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ outputs.workload_identity_provider_ro }}
          service_account: ${{ outputs.service_account_email_ro }}
          
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
```

### Conditional Terraform Operations

With dual service accounts, you can also conditionally run different Terraform operations:

```yaml
  - name: Terraform Plan (All Branches)
    run: terraform plan

  - name: Terraform Apply (Write-Enabled Branches Only)
    if: contains(fromJSON('["refs/heads/main", "refs/heads/master"]'), github.ref)
    run: terraform apply -auto-approve
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
    "khan-academy" = {
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
    "khan-academy-staging" = {
      required_services = ["storage", "pubsub"]
    }
    "khan-shared-services" = {
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
    "khan-academy" = {
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
    "khan-academy" = {
      required_services = ["storage"]
    }
  }
  
  # Terraform state bucket defaults to: terraform-khan-static-site-static-site-prod
}
```

### Terraform Configuration with Cloud Run and Cloud Build

```hcl
# CI for webapp Terraform configuration that manages Cloud Run services and Cloud Build
module "webapp_prod_ci" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  service_name      = "webapp-prod"
  github_repository = "Khan/webapp"
  
  # This Terraform config manages Cloud Run services, jobs, and Cloud Build
  target_projects = {
    "khan-academy" = {
      required_services = ["run", "cloudbuild", "storage"]
    }
  }
  
  # Terraform state bucket defaults to: terraform-khan-webapp-webapp-prod
}
```

### Terraform Configuration with Dual Service Accounts

```hcl
# CI for API production Terraform configuration with separate service accounts for main and PR branches
module "api_prod_ci" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/github-ci-bootstrap?ref=v1.0.0"

  service_name      = "api-prod"
  github_repository = "Khan/api"
  
  # Configure which branches can use the write-enabled service account
  write_branch_patterns = ["main", "master"]
  
  target_projects = {
    "khan-academy" = {
      required_services = ["cloudfunctions", "storage", "pubsub", "cloudbuild"]
    }
  }
  
  # Secrets that both service accounts need access to
  secret_ids = [
    "projects/khan-academy/secrets/api-key",
    "projects/khan-academy/secrets/database-url"
  ]
  
  # Terraform state bucket defaults to: terraform-khan-api-api-prod
}
```
