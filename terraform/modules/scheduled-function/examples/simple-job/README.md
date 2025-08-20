# Simple Cloud Run Job Example

This example demonstrates how to use the scheduled-function module to create a Cloud Run Job that runs on a schedule.

## What this example creates

- A Cloud Run Job that processes data daily at 2 AM
- Cloud Scheduler job to trigger the Cloud Run Job
- Service account with appropriate permissions
- Storage bucket for job source code
- Secret Manager IAM bindings

## Key differences from Cloud Functions

1. **Execution Type**: Set `execution_type = "job"` to create a Cloud Run Job instead of a Cloud Function
2. **Triggering**: Cloud Run Jobs are triggered via HTTP calls to the Cloud Run Jobs API (not PubSub)
3. **Resource Configuration**: Use `job_cpu`, `job_memory`, `job_timeout` instead of function-specific variables
4. **Command**: Specify the command to run with `job_command` and `job_args`

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
module "daily_data_processor" {
  source = "../.."

  function_name      = "daily-data-processor"
  execution_type     = "job"  # This creates a Cloud Run Job
  
  # Job-specific configuration
  job_cpu    = "2000m"        # 2 CPU cores
  job_memory = "2Gi"          # 2 GB memory
  job_timeout = "7200"        # 2 hours timeout
  
  # Container image (build and push separately)
  job_image = "gcr.io/YOUR_PROJECT_ID/daily-data-processor:latest"
  
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

- **Container Image Required**: You need to build and push a Docker image to Container Registry or Artifact Registry before deploying.
- **Dockerfile**: Include a `Dockerfile` in your source directory to build the container image.
- **Manual Build/Push**: The module creates the job definition but doesn't handle container image building/pushing.
- **Build Process**: Use `docker build` and `docker push` or `gcloud builds submit` to create your container image.
- Jobs are triggered via HTTP calls to the Cloud Run Jobs API, not via PubSub like Cloud Functions.
- Jobs can run for longer periods and have more resources than Cloud Functions.
