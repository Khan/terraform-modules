# Terraform Modules

This repository contains shared, reusable Terraform modules designed to simplify infrastructure provisioning and promote consistency across projects.

## Overview

These modules encapsulate common infrastructure patterns and best practices, allowing teams to quickly deploy standardized resources without duplicating configuration code.

## Usage

To use a module from this repository, reference it in your Terraform configuration with a specific version:

```hcl
module "scheduled_function" {
  source = "git::https://github.com/your-org/terraform-modules.git//terraform/modules/scheduled-function?ref=v1.0.0"
  
  # Module-specific variables
  function_name = "my-scheduled-function"
  schedule_expression = "rate(1 hour)"
}
```

Always use a specific version tag (e.g., `?ref=v1.0.0`) to ensure consistent deployments and avoid unexpected changes.

## Structure

Each module is self-contained in its own directory under `terraform/modules/` and includes:

- **main.tf** - Primary resource definitions
- **variables.tf** - Input variable declarations
- **outputs.tf** - Output value definitions
- **versions.tf** - Provider version constraints
- **README.md** - Module-specific documentation (auto-generated)
- **CHANGELOG.md** - Module changelog (auto-generated)
- **examples/** - Usage examples and test cases

## Versioning

Module versions are managed manually using GitHub Actions.

See the [Contributing Guide](.github/CONTRIBUTING.md#releases) for details on creating releases.

Check the [Releases](../../releases) page for available versions.
