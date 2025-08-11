# Scheduled Cloud Function Module
# This module creates a complete scheduled Cloud Function setup with all necessary components

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

# Service account for the Cloud Function
resource "google_service_account" "function_sa" {
  project      = var.project_id
  account_id   = "${var.function_name}-sa"
  display_name = "Service Account for ${var.function_name} function"
  description  = "Service account used by the ${var.function_name} scheduled Cloud Function"
}

# Storage bucket for function source code
resource "google_storage_bucket" "function_bucket" {
  project                     = var.project_id
  name                        = "${var.function_name}-source-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

# Create function source archive
data "archive_file" "function_archive" {
  type        = "zip"
  output_path = "${path.module}/${var.function_name}-function.zip"
  source_dir  = abspath(var.source_dir)
  excludes    = var.excludes
}

# Upload function archive to storage bucket
# The object name includes the source code hash, ensuring:
# 1. Cloud Function redeploys when source code changes (new hash = new object name)
# 2. Terraform automatically deletes old zip files when hash changes (resource replacement)
# 3. No manual cleanup or lifecycle rules needed - Terraform handles it
resource "google_storage_bucket_object" "function_archive" {
  name   = "${var.function_name}-function-${data.archive_file.function_archive.output_sha}.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_archive.output_path
}

# PubSub topic for triggering the function
resource "google_pubsub_topic" "function_topic" {
  project = var.project_id
  name    = "${var.function_name}-topic"
}

# Cloud Scheduler job
resource "google_cloud_scheduler_job" "function_scheduler" {
  project     = var.project_id
  name        = "${var.function_name}-scheduler"
  description = var.description
  schedule    = var.schedule
  time_zone   = var.time_zone

  pubsub_target {
    topic_name = google_pubsub_topic.function_topic.id
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

# The main Cloud Function
resource "google_cloudfunctions2_function" "function" {
  project     = var.project_id
  name        = var.function_name
  description = var.description
  location    = var.region

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_archive.name
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
    pubsub_topic   = google_pubsub_topic.function_topic.id
    retry_policy   = var.retries_enabled ? "RETRY_POLICY_RETRY" : "RETRY_POLICY_DO_NOT_RETRY"
  }
} 