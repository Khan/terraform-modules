# Simple Cloud Run Job Example

This example demonstrates how to use the scheduled-job module to create a Cloud Run Job that runs on a schedule, with automatic container image building using the cloud-build-docker module.

## What this example creates

- A Cloud Run Job that processes data daily at 2 AM
- Cloud Scheduler job to trigger the Cloud Run Job
- Service account with appropriate permissions
- Container image built automatically using Cloud Build
- Secret Manager IAM bindings

## Key differences from Cloud Functions

1. **Execution Type**: Set `execution_type = "job"` to create a Cloud Run Job instead of a Cloud Function
2. **Triggering**: Cloud Run Jobs are triggered via HTTP calls to the Cloud Run Jobs API (not PubSub)
3. **Resource Configuration**: Use `job_cpu`, `job_memory`, `job_timeout` instead of function-specific variables
4. **Container Images**: Cloud Run Jobs require container images (built automatically with cloud-build-docker module)
5. **Command**: Specify the command to run with `job_command` and `job_args`

## Usage

1. Set your project variables:

   ```bash
   export TF_VAR_project_id="your-gcp-project"
   export TF_VAR_secrets_project_id="your-secrets-project"
   ```

2. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. The job will be scheduled to run daily at 2 AM UTC.

## Configuration

The main configuration differences for Cloud Run Jobs:

```hcl
# Build the container image using Cloud Build
module "daily_data_processor_image" {
  source = "../../../cloud-build-docker"

  image_name       = "daily-data-processor"
  context_path     = "./job-code"
  project_id       = var.project_id
  image_tag_suffix = "latest"
}

# Deploy the scheduled job
module "daily_data_processor" {
  source = "../.."

  job_name      = "daily-data-processor"
  execution_type     = "job"  # This creates a Cloud Run Job
  
  # Job-specific configuration
  job_cpu    = "2000m"        # 2 CPU cores
  job_memory = "2Gi"          # 2 GB memory
  job_timeout = "7200s"        # 2 hours timeout
  
  # Container image (use the built image)
  job_image = module.daily_data_processor_image.image_digest
  
  # Command to run
  job_command = ["python", "processor.py"]
  job_args    = []            # Additional arguments if needed
  
  # ... other configuration
}
```

## Job Code

The job code in `job-code/processor.py` is a simple Python script that:

- Logs the start of processing
- Accesses environment variables (including secrets)
- Simulates data processing work
- Returns appropriate exit codes

## Important Notes

- **Automatic Image Building**: The cloud-build-docker module automatically builds and pushes your container image using Cloud Build.
- **Dockerfile**: Include a `Dockerfile` in your source directory to build the container image.
- **Digest Tracking**: The module uses image digests for precise versioning and automatic redeployment when code changes.
- **Branch-based Caching**: Cloud Build caches layers based on branch names for faster builds.
- Jobs are triggered via HTTP calls to the Cloud Run Jobs API, not via PubSub like Cloud Functions.
- Jobs can run for longer periods and have more resources than Cloud Functions.
