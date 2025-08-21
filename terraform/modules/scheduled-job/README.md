# terraform-scheduled-job-module

A reusable Terraform module for scheduled Google Cloud Functions and Cloud Run Jobs.

## Features

Creates a complete scheduled setup:
- **Cloud Function (2nd gen)** OR **Cloud Run Job** with configurable runtime
- Cloud Scheduler with cron-based scheduling  
- PubSub topic for reliable triggering (Cloud Functions only)
- Service account with least-privilege permissions
- Storage bucket with lifecycle management
- Secret Manager IAM bindings
- Source code change detection

## Quick Start

### Cloud Function Example
```hcl
module "my_daily_task" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"

  job_name      = "my-daily-task"
  execution_type     = "function"  # Default, can be omitted
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

### Cloud Run Job Example
```hcl
# Build the container image using Cloud Build
module "data_processor_image" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/cloud-build-docker?ref=v1.0.0"

  image_name       = "data-processor"
  context_path     = "./jobs/data-processor"
  project_id       = "my-gcp-project"
  image_tag_suffix = "latest"
}

# Deploy the scheduled job
module "my_data_processor" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"

  job_name      = "my-data-processor"
  execution_type     = "job"
  project_id         = "my-gcp-project"
  secrets_project_id = "my-secrets-gcp-project"
  source_dir         = "./jobs/data-processor"
  main_file          = "processor.py"
  schedule           = "0 2 * * *"  # 2 AM daily
  description        = "Daily data processing job"

  # Job-specific configuration
  job_cpu    = "2000m"
  job_memory = "2Gi"
  job_timeout = "7200s"  # 2 hours
  job_image  = module.data_processor_image.image_digest  # Use the built image

  environment_variables = {
    ENV = "production"
  }

  secrets = [
    {
      env_var_name = "DATABASE_URL"
      secret_id    = "database-connection"
      version      = "latest"
    }
  ]
}
```

## Examples

Complete working examples are available in the [`examples/`](./examples/) directory:

- **[`simple-function/`](./examples/simple-function/)** - Basic scheduled Cloud Function with minimal configuration
- **[`simple-job/`](./examples/simple-job/)** - Basic scheduled Cloud Run Job with minimal configuration

Each example includes:
- Complete Terraform configuration
- Sample code with `requirements.txt`
- Documentation on how to deploy and test

## Cloud Functions vs Cloud Run Jobs

### When to use Cloud Functions (`execution_type = "function"`)
- **Short-running tasks** (up to 60 minutes)
- **Event-driven workloads** (PubSub, HTTP, etc.)
- **Serverless scaling** (0 to many instances)
- **Simple Python/Node.js/Go applications**
- **Cost-effective for sporadic workloads**

### When to use Cloud Run Jobs (`execution_type = "job"`)
- **Long-running batch processes** (up to 24 hours)
- **Resource-intensive workloads** (high CPU/memory)
- **Scheduled batch jobs** (ETL, data processing, reports)
- **Container-based applications**
- **Parallel processing** (multiple tasks)
- **Custom runtimes** (any container image)

### Key Differences

| Feature | Cloud Functions | Cloud Run Jobs |
|---------|----------------|----------------|
| **Max Runtime** | 60 minutes | 24 hours |
| **Triggering** | PubSub, HTTP, etc. | HTTP API calls |
| **Scaling** | Auto-scaling | Manual execution |
| **Resources** | Limited CPU/memory | Configurable CPU/memory |
| **Container** | Runtime-based | Custom container images |
| **Parallelism** | Multiple instances | Configurable parallelism |

### Cost Considerations

**Pricing is extremely similar** between Cloud Functions (2nd gen) and Cloud Run Jobs since both are billed as Cloud Run services. See the [official Cloud Run pricing page](https://cloud.google.com/run/pricing) for current rates.

*Note: Both execution types use the same pricing model, so cost should not be the primary factor in your decision.*

## Cross-Repository Usage

### Use Everywhere
```hcl
# Production: Pin to specific version
module "backup" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  # ... config
}

# Development: Use latest
module "test_function" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job"
  # ... config
}
```

## Usage Examples

### Multiple Functions
```hcl
module "daily_backup" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  
  job_name = "daily-backup"
  schedule      = "0 2 * * *"  # 2 AM daily
  source_dir    = "./functions/backup"
  main_file     = "backup.py"
  # ... other config
}

module "weekly_reports" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  
  job_name = "weekly-reports"
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
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  
  job_name      = "data-processor"
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
- `job_name` - Unique name for your function or job
- `project_id` - GCP project for resources
- `secrets_project_id` - GCP project containing secrets
- `source_dir` - Path to function/job code
- `main_file` - Python file name (e.g., "main.py"), relative to `source_dir`.
- `schedule` - Cron expression (e.g., "0 9 * * 1-5")
- `description` - Function/job description
- `owner` - The owner/team responsible for this scheduled job

### Optional (with defaults)
- `execution_type` - "function" or "job" ("function")
- `region` - GCP region ("us-central1")
- `runtime` - Function runtime ("python311")
- `memory` - Memory allocation for functions ("2048M")
- `timeout_seconds` - Timeout for functions (60)
- `environment_variables` - Environment vars ({})
- `secrets` - Secret Manager secrets ([])
- `tags` - A map of tags to assign to all resources ({})

### Cloud Run Job specific (when `execution_type = "job"`)
- `job_cpu` - CPU allocation (e.g., "1000m", "2") ("1000m")
- `job_memory` - Memory allocation (e.g., "512Mi", "2Gi") ("512Mi")
- `job_timeout` - Timeout duration (e.g., "3600s", "1h", "2h30m") ("3600s")
- `job_parallelism` - Number of parallel executions (1)
- `job_task_count` - Number of tasks to run (1)
- `job_command` - Command to run (["python", "main.py"])
- `job_args` - Command arguments ([])
- `job_image` - Container image URL (required)

## Outputs

- `resource_name` - Name of deployed function or job
- `function_url` - Function URL (when `execution_type = "function"`)
- `service_account_email` - Service account email
- `scheduler_job_name` - Scheduler job name
- `pubsub_topic_name` - PubSub topic name (when `execution_type = "function"`)
- `storage_bucket_name` - Storage bucket name
- `execution_type` - The execution type used

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
├── jobs/
│   └── data-processor/
│       ├── processor.py
│       ├── requirements.txt
│       └── Dockerfile
└── README.md
```

## Code Structure

### Cloud Functions

Your source directory must contain:

```
functions/my-task/
├── main.py              # Entry point function
└── requirements.txt     # Python dependencies (if needed)
```

#### Python Function Code

```python
# functions/my-task/main.py
import functions_framework

@functions_framework.cloud_event
def main(cloud_event):
    """Function entry point"""
    print("Task running!")
    return "Success"
```

### Cloud Run Jobs

Your source directory should contain:

```
jobs/my-job/
├── processor.py         # Main job script
├── requirements.txt     # Python dependencies
└── Dockerfile          # Container definition
```

#### Python Job Code

```python
# jobs/my-job/processor.py
#!/usr/bin/env python3
import os
import sys
import logging

def main():
    """Main function for the Cloud Run Job."""
    logging.info("Starting job...")
    # Your job logic here
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

#### Dockerfile Example

```dockerfile
# jobs/my-job/Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["python", "processor.py"]
```

### Dependencies

For both Cloud Functions and Cloud Run Jobs, include a `requirements.txt` file if your code uses external packages. Cloud Functions automatically install dependencies during deployment, while Cloud Run Jobs require a Dockerfile to build the container image.

### Building and Pushing Container Images for Cloud Run Jobs

For Cloud Run Jobs, you need to build and push your container image. The recommended approach is to use the `cloud-build-docker` module:

```hcl
# Build the container image using Cloud Build
module "my_job_image" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/cloud-build-docker?ref=v1.0.0"

  image_name       = "my-job"
  context_path     = "./jobs/my-job"
  project_id       = var.project_id
  image_tag_suffix = "latest"
}

# Use the built image in your scheduled job
module "my_scheduled_job" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  
  # ... other configuration
  job_image = module.my_job_image.image_digest
}
```

**Benefits of using the cloud-build-docker module:**
- **Automatic building**: No manual Docker commands needed
- **Branch-based caching**: Faster builds with layer caching
- **Digest tracking**: Precise image versioning in Terraform
- **Consistent builds**: Same build process across environments

**Alternative manual approach:**
```bash
# Build the image
docker build -t gcr.io/YOUR_PROJECT_ID/YOUR_JOB_NAME:latest ./jobs/your-job

# Push to Container Registry
docker push gcr.io/YOUR_PROJECT_ID/YOUR_JOB_NAME:latest
```

Or use Cloud Build directly:
```bash
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/YOUR_JOB_NAME:latest ./jobs/your-job
```

## Resource Tagging

All resources created by this module are automatically tagged with common metadata:

### Automatic Tags
- `terraform_module` - Set to "scheduled-job"
- `scheduled_job_name` - The name of your function/job
- `owner` - The owner/team responsible for this scheduled job

### Custom Tags
You can add custom tags using the `tags` variable:

```hcl
module "my_function" {
  source = "git::https://github.com/Khan/terraform-modules.git//terraform/modules/scheduled-job?ref=v1.0.0"
  
  job_name = "my-function"
  owner   = "data-team"
  # ... other configuration
  
  tags = {
    "environment" = "production"
    "team"        = "data-engineering"
    "cost-center" = "infrastructure"
  }
}
```

### Supported Resources
The following resources support tagging/labeling:
- **Storage Buckets** - Labels applied
- **Storage Objects** - Metadata applied
- **PubSub Topics** - Labels applied
- **Cloud Functions** - Labels applied
- **Cloud Run Jobs** - Labels applied

## Common Cron Patterns

| Schedule | Description |
|----------|-------------|
| `"0 9 * * 1-5"` | 9 AM weekdays |
| `"0 */6 * * *"` | Every 6 hours |
| `"0 2 * * *"` | 2 AM daily |
| `"0 9 * * 1"` | Monday 9 AM |
| `"*/15 * * * *"` | Every 15 minutes |