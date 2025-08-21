# Scheduled Cloud Function/Job Module
# This module creates a complete scheduled Cloud Function or Cloud Run Job setup with all necessary components

# Required providers
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
  }
}

# Service account for the Cloud Function/Job
resource "google_service_account" "function_sa" {
  project      = var.project_id
  account_id   = "${var.job_name}-sa"
  display_name = "Service Account for ${var.job_name} ${var.execution_type}"
  description  = "Service account used by the ${var.job_name} scheduled ${var.execution_type}"
}

# Storage bucket for function source code (only for Cloud Functions)
resource "google_storage_bucket" "function_bucket" {
  count = var.execution_type == "function" ? 1 : 0

  project                     = var.project_id
  name                        = "${var.job_name}-source-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

# Create function source archive (only for Cloud Functions)
data "archive_file" "function_archive" {
  count = var.execution_type == "function" ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/${var.job_name}-function.zip"
  source_dir  = var.source_dir
  excludes    = var.excludes
}

# Upload function archive to storage bucket (only for Cloud Functions)
# The object name includes the source code hash, ensuring:
# 1. Cloud Function redeploys when source code changes (new hash = new object name)
# 2. Terraform automatically deletes old zip files when hash changes (resource replacement)
# 3. No manual cleanup or lifecycle rules needed - Terraform handles it
resource "google_storage_bucket_object" "function_archive" {
  count = var.execution_type == "function" ? 1 : 0

  name   = "${var.job_name}-function-${data.archive_file.function_archive[0].output_sha}.zip"
  bucket = google_storage_bucket.function_bucket[0].name
  source = data.archive_file.function_archive[0].output_path
}

# PubSub topic for triggering the Cloud Function (only created when execution_type is "function")
resource "google_pubsub_topic" "function_topic" {
  count = var.execution_type == "function" ? 1 : 0

  project = var.project_id
  name    = "${var.job_name}-topic"
}

# Cloud Scheduler job for Cloud Function (only created when execution_type is "function")
resource "google_cloud_scheduler_job" "function_scheduler" {
  count = var.execution_type == "function" ? 1 : 0

  project     = var.project_id
  name        = "${var.job_name}-scheduler"
  description = var.description
  schedule    = var.schedule
  time_zone   = var.time_zone

  pubsub_target {
    topic_name = google_pubsub_topic.function_topic[0].id
    data       = base64encode("{}")
  }
}

# Secret Manager IAM bindings for each secret
resource "google_secret_manager_secret_iam_member" "function_secret_access" {
  for_each = {
    for secret in var.secrets : secret.env_var_name => secret
  }

  project   = var.secrets_project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_sa.email}"
}

# IAM binding for Cloud Run Jobs (when execution_type is "job")
# The service account needs permission to invoke Cloud Run Jobs via the API
resource "google_project_iam_member" "job_invoker" {
  count = var.execution_type == "job" ? 1 : 0

  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# The main Cloud Function (only created when execution_type is "function")
resource "google_cloudfunctions2_function" "function" {
  count = var.execution_type == "function" ? 1 : 0

  project     = var.project_id
  name        = var.job_name
  description = var.description
  location    = var.region

  # Ensure service account is created before the function
  depends_on = [google_service_account.function_sa]

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket[0].name
        object = google_storage_bucket_object.function_archive[0].name
      }
    }

    environment_variables = merge(
      var.build_environment_variables,
      {
        GOOGLE_FUNCTION_SOURCE = var.main_file
      }
    )
  }

  service_config {
    max_instance_count    = var.max_instance_count
    min_instance_count    = var.min_instance_count
    available_memory      = var.memory
    timeout_seconds       = var.timeout_seconds
    service_account_email = google_service_account.function_sa.email

    environment_variables = var.environment_variables

    # Dynamic block for secret environment variables
    dynamic "secret_environment_variables" {
      for_each = var.secrets
      content {
        key        = secret_environment_variables.value.env_var_name
        project_id = var.secrets_project_id
        secret     = secret_environment_variables.value.secret_id
        version    = secret_environment_variables.value.version
      }
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.function_topic[0].id
    retry_policy   = var.retries_enabled ? "RETRY_POLICY_RETRY" : "RETRY_POLICY_DO_NOT_RETRY"
  }
}

# Cloud Run Job (only created when execution_type is "job")
resource "google_cloud_run_v2_job" "job" {
  count = var.execution_type == "job" ? 1 : 0

  project  = var.project_id
  name     = var.job_name
  location = var.region

  # Allow Terraform to manage the job lifecycle
  deletion_protection = false

  # Ensure service account is created before the job
  depends_on = [google_service_account.function_sa]

  lifecycle {
    precondition {
      condition     = var.job_image != null
      error_message = "job_image is required when execution_type is 'job'."
    }
  }

  template {
    task_count  = var.job_task_count
    parallelism = var.job_parallelism

    template {
      containers {
        image = var.job_image

        command = var.job_command
        args    = var.job_args

        resources {
          limits = {
            cpu    = var.job_cpu
            memory = var.job_memory
          }
        }

        # Environment variables
        dynamic "env" {
          for_each = var.environment_variables
          content {
            name  = env.key
            value = env.value
          }
        }

        # Secret environment variables
        dynamic "env" {
          for_each = var.secrets
          content {
            name = env.value.env_var_name
            value_source {
              secret_key_ref {
                secret  = "projects/${var.secrets_project_id}/secrets/${env.value.secret_id}"
                version = env.value.version
              }
            }
          }
        }
      }

      service_account = google_service_account.function_sa.email
      timeout         = var.job_timeout
    }
  }
}




# Cloud Scheduler job for Cloud Run Job (only created when execution_type is "job")
resource "google_cloud_scheduler_job" "job_scheduler" {
  count = var.execution_type == "job" ? 1 : 0

  project     = var.project_id
  name        = "${var.job_name}-job-scheduler"
  description = var.description
  schedule    = var.schedule
  time_zone   = var.time_zone

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${var.job_name}:run"
    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.function_sa.email
    }
  }
} 