# Culture Cron Bootstrap Example

This example demonstrates how to use the GitHub CI Bootstrap module from the shared Terraform modules repository to set up CI/CD infrastructure for the Culture Cron project.

## Overview

This configuration uses the reusable `github-ci-bootstrap` module to create:

- Service account for GitHub Actions
- Workload Identity Federation for keyless authentication
- IAM permissions for Cloud Functions, Storage, Pub/Sub, and Scheduler
- Access to secrets in Google Secret Manager
- Terraform state bucket permissions

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
- **More consistent** - Standardized CI/CD setup across projects
- **Better documented** - Module includes comprehensive documentation

## Configuration

The module is configured with:

- **Project**: `khan-internal-services` (Culture Cron infrastructure)
- **Secrets**: `khan-academy` (Slack token storage)
- **Repository**: `Khan/culture-cron` (GitHub repository)
- **Services**: Cloud Functions, Storage, Pub/Sub, Scheduler

## Outputs

After applying, you'll get the service account email and Workload Identity provider needed for GitHub Actions workflows.

## Migration

To migrate from the existing bootstrap:

1. **Backup current state:**
   ```bash
   cd ../../bootstrap
   terraform state pull > backup.tfstate
   ```

2. **Apply this example configuration**

3. **Update GitHub Actions workflows** to use the new service account (if the name changed)

The resource naming in the module follows the same pattern, so most resources should match existing ones. 