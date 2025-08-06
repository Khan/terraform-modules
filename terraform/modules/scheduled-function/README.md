# terraform-scheduled-function-module

A reusable Terraform module for scheduled Google Cloud Functions.

## Features

Creates a complete scheduled function setup:
- Cloud Function (2nd gen) with configurable runtime
- Cloud Scheduler with cron-based scheduling  
- PubSub topic for reliable triggering
- Service account with least-privilege permissions
- Storage bucket with lifecycle management
- Secret Manager IAM bindings
- Source code change detection

## Quick Start

```hcl
module "my_daily_task" {
  source = "git::https://github.com/Khan/terraform-scheduled-function-module.git?ref=v1.0.0"

  function_name      = "my-daily-task"
  project_id         = "my-gcp-project"
  secrets_project_id = "my-secrets-gcp-project"
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

}
```

## Requirements & Inputs

### Required
- `function_name` - Unique name for your function
- `project_id` - GCP project for resources
- `secrets_project_id` - GCP project containing secrets
- `source_dir` - Path to function code
- `main_file` - Python file name (e.g., "main.py"), relative to `source_dir`.
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

### Required Files

Your source directory must contain:

```
functions/my-task/
├── main.py              # Entry point function
└── requirements.txt     # Python dependencies (if needed)
```

### Python Function Code

```python
# functions/my-task/main.py
import functions_framework

@functions_framework.cloud_event
def main(cloud_event):
    """Function entry point"""
    print("Task running!")
    return "Success"
```

### Dependencies

If your function uses external packages, include a `requirements.txt` file. Cloud Functions automatically install dependencies from `requirements.txt` during deployment. No local installation is needed - the module simply packages your source code and lets Cloud Functions handle dependency management.

## Common Cron Patterns

| Schedule | Description |
|----------|-------------|
| `"0 9 * * 1-5"` | 9 AM weekdays |
| `"0 */6 * * *"` | Every 6 hours |
| `"0 2 * * *"` | 2 AM daily |
| `"0 9 * * 1"` | Monday 9 AM |
| `"*/15 * * * *"` | Every 15 minutes |
