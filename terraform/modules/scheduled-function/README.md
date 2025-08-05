# terraform-scheduled-function-module

A reusable Terraform module for scheduled Google Cloud Functions. Reduces 145 lines of infrastructure code to just 10-25 lines.

## Features

Creates a complete scheduled function setup:
- Cloud Function (2nd gen) with configurable runtime
- Cloud Scheduler with cron-based scheduling  
- PubSub topic for reliable triggering
- Service account with least-privilege permissions
- Storage bucket with lifecycle management
- Secret Manager IAM bindings
- Automatic dependency installation
- Source code change detection

## Quick Start

```hcl
module "my_daily_task" {
  source = "git::https://github.com/Khan/terraform-scheduled-function-module.git?ref=v1.0.0"

  function_name      = "my-daily-task"
  project_id         = "my-gcp-project"
  secrets_project_id = "my-secrets-project"
  source_dir         = "./functions/my-task"
  main_file          = "main.py"
  schedule           = "0 9 * * 1-5"  # 9 AM weekdays
  description        = "My daily automated task"

  environment_variables = {
    ENV = "production"
  }

  secrets = [
    {
      env_var_name = "API_TOKEN"
      secret_id    = "my-api-token"
      version      = "latest"
    }
  ]
}
```

## Cross-Repository Usage

### Setup Once
1. Create this module as a separate repository
2. Tag releases (e.g., `v1.0.0`)
3. Reference from any repository using Git source

### Use Everywhere
```hcl
# Production: Pin to specific version
module "backup" {
  source = "git::https://github.com/YourOrg/terraform-scheduled-function-module.git?ref=v1.0.0"
  # ... config
}

# Development: Use latest
module "test_function" {
  source = "git::https://github.com/YourOrg/terraform-scheduled-function-module.git"
  # ... config
}
```

## Examples

### Multiple Functions
```hcl
module "daily_backup" {
  source = "git::https://github.com/YourOrg/terraform-scheduled-function-module.git?ref=v1.0.0"
  
  function_name = "daily-backup"
  schedule      = "0 2 * * *"  # 2 AM daily
  source_dir    = "./functions/backup"
  main_file     = "backup.py"
  # ... other config
}

module "weekly_reports" {
  source = "git::https://github.com/YourOrg/terraform-scheduled-function-module.git?ref=v1.0.0"
  
  function_name = "weekly-reports"
  schedule      = "0 9 * * 1"  # Monday 9 AM
  source_dir    = "./functions/reports"
  main_file     = "reports.py"
  memory        = "4096M"
  # ... other config
}
```

### Advanced Configuration
```hcl
module "data_processor" {
  source = "git::https://github.com/YourOrg/terraform-scheduled-function-module.git?ref=v1.0.0"
  
  function_name      = "data-processor"
  project_id         = var.project_id
  secrets_project_id = var.secrets_project_id
  source_dir         = "./functions/processor"
  main_file          = "processor.py"
  schedule           = "0 */6 * * *"  # Every 6 hours
  
  # Resource configuration
  memory               = "4096M"
  timeout_seconds      = 300
  max_instance_count   = 3
  
  # Multiple secrets
  secrets = [
    {
      env_var_name = "DATABASE_URL"
      secret_id    = "postgres-connection"
      version      = "latest"
    },
    {
      env_var_name = "API_KEY"
      secret_id    = "external-api-key"
      version      = "2"
    }
  ]
  
  # Custom dependency installation
  dependency_install_script = "pip install -r requirements.txt -t . && pip install tensorflow -t ."
}
```

## Migration from Manual Resources

### Before (145 lines)
```hcl
resource "google_service_account" "function_sa" { ... }
resource "google_storage_bucket" "function_bucket" { ... }
resource "null_resource" "install_dependencies" { ... }
data "archive_file" "function_archive" { ... }
resource "google_storage_bucket_object" "function_archive" { ... }
resource "google_pubsub_topic" "function_topic" { ... }
resource "google_cloud_scheduler_job" "function_scheduler" { ... }
resource "google_cloudfunctions2_function" "function" { ... }
# + IAM bindings, etc.
```

### After (20 lines)
```hcl
module "my_function" {
  source = "git::https://github.com/YourOrg/terraform-scheduled-function-module.git?ref=v1.0.0"
  
  function_name = "my-function"
  project_id    = var.project_id
  source_dir    = "./functions/my-function"
  main_file     = "main.py"
  schedule      = "0 9 * * 1-5"
  description   = "My function"
  
  secrets = [{ env_var_name = "TOKEN", secret_id = "my-token", version = "latest" }]
}
```

**Result: 83% less code, same functionality**

## Requirements & Inputs

### Required
- `function_name` - Unique name for your function
- `project_id` - GCP project for resources
- `secrets_project_id` - GCP project containing secrets
- `source_dir` - Path to function code
- `main_file` - Python file name (e.g., "main.py")
- `schedule` - Cron expression (e.g., "0 9 * * 1-5")
- `description` - Function description

### Optional (with defaults)
- `region` - GCP region ("us-central1")
- `runtime` - Function runtime ("python311")
- `memory` - Memory allocation ("2048M")
- `timeout_seconds` - Timeout (60)
- `environment_variables` - Environment vars ({})
- `secrets` - Secret Manager secrets ([])

## Outputs

- `function_name` - Name of deployed function
- `function_url` - Function URL
- `service_account_email` - Function service account
- `scheduler_job_name` - Scheduler job name

## Repository Structure

```
your-app-repo/
├── terraform/
│   └── main.tf                    # Uses module
├── functions/
│   ├── daily-backup/
│   │   ├── main.py
│   │   └── requirements.txt
│   └── reports/
│       ├── main.py
│       └── requirements.txt
└── README.md
```

## Function Code Structure

```python
# functions/my-task/main.py
import functions_framework

@functions_framework.cloud_event
def main(cloud_event):
    """Function entry point"""
    print("Task running!")
    return "Success"
```

## Versioning & Deployment

```bash
# 1. Create module repository
git clone <module-repo> terraform-scheduled-function-module
cd terraform-scheduled-function-module
git tag v1.0.0
git push origin v1.0.0

# 2. Use in any repository
cd your-app-repo/terraform
terraform init
terraform plan
terraform apply
```

## Common Cron Patterns

| Schedule | Description |
|----------|-------------|
| `"0 9 * * 1-5"` | 9 AM weekdays |
| `"0 */6 * * *"` | Every 6 hours |
| `"0 2 * * *"` | 2 AM daily |
| `"0 9 * * 1"` | Monday 9 AM |
| `"*/15 * * * *"` | Every 15 minutes |

## License

Maintained by Khan Academy. 