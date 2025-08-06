# Culture Cron GitHub Terraform CI Bootstrap Example

This example demonstrates how to use the GitHub Terraform CI Bootstrap module from the shared Terraform modules repository to set up CI/CD infrastructure for managing the Culture Cron Terraform configuration in GitHub Actions.

## Overview

This configuration uses the reusable `github-ci-bootstrap` module to create:

- Service account for running Terraform operations in GitHub Actions (in khan-internal-services project)
- Workload Identity Federation using shared pool for keyless authentication
- IAM permissions for deploying Cloud Functions, Storage, Pub/Sub, and Scheduler resources via Terraform
- Access to secrets in Google Secret Manager that the Terraform configuration needs
- Permissions for Terraform state bucket management

## Architecture

- **Service Account**: `culture-cron-prod-ci` created in `khan-internal-services` project for Terraform operations
- **Shared Pool**: Uses `khan-internal-services-github-ci` pool (shared by all Terraform CI setups)
- **Unique Provider**: `culture-cron-prod-provider` within the shared pool
- **Target Project**: Terraform configuration deploys to `khan-internal-services` with permissions for specified services
- **State Isolation**: Dedicated state bucket for this Terraform configuration

## Purpose

This creates the necessary infrastructure for managing Terraform in GitHub Actions CI:
- `terraform plan` - Review infrastructure changes in CI
- `terraform apply` - Deploy infrastructure changes via CI
- `terraform destroy` - (if needed) Clean up resources via CI

Each Terraform configuration managed in CI gets its own service account to ensure:
- **Isolation**: Separate permissions and state for prod/staging/dev configurations
- **Security**: Least privilege access to only required GCP services
- **Traceability**: Clear audit trail of which Terraform CI account made which changes

## Usage

1. **Navigate to this directory:**
   ```bash
   cd terraform/examples/bootstrap-with-module
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the plan:**
   ```bash
   terraform plan
   ```

4. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Comparison

### Before (Direct Resources)
The original bootstrap configuration had ~150 lines of Terraform with explicit resource definitions for service accounts, IAM bindings, and Workload Identity setup.

### After (Module)
This example reduces the configuration to ~25 lines by using the reusable module, making it:
- **Easier to maintain** - Updates happen in one place
- **Less error-prone** - Tested, reusable components
- **More consistent** - Standardized Terraform CI setup across projects
- **Better documented** - Module includes comprehensive documentation
- **Shared Infrastructure** - Uses centralized Workload Identity Pool

## Configuration

The module is configured for the Culture Cron production Terraform configuration managed in CI:

- **Terraform Configuration**: `culture-cron-prod` (production environment managed in CI)
- **Repository**: `Khan/culture-cron` (GitHub repository containing Terraform code)
- **Target Project**: `khan-internal-services` with Cloud Functions, Storage, Pub/Sub, Scheduler services
- **State Bucket**: `terraform-khan-culture-cron-culture-cron-prod` (automatically computed from repository and service)
- **Secrets**: `khan-academy` (Slack token storage needed by the Terraform configuration)

## Outputs

After applying, you'll get the service account email and Workload Identity provider needed for configuring GitHub Actions workflows to manage Terraform in CI.

## Migration

To migrate from an existing bootstrap setup:

1. **Backup current state:**
   ```bash
   cd ../../bootstrap
   terraform state pull > backup.tfstate
   ```

2. **Apply this example configuration**

3. **Update GitHub Actions workflows** to use the new service account for managing Terraform in CI

The new architecture uses shared infrastructure, so the first GitHub Terraform CI setup to be deployed will create the shared pool, and subsequent Terraform configurations will reuse it. 