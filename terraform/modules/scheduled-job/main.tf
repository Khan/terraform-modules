# Scheduled Cloud Function/Job Module
# This module creates a complete scheduled Cloud Function or Cloud Run Job setup with all necessary components

# Required providers
terraform {
  # 1.11+ for write-only arguments (1.10 introduced ephemeral resources).
  required_version = ">= 1.11.0"

  required_providers {
    google = {
      # 7.19.0 added the write-only sensitive_labels variants
      # (auth_token_wo) on google_monitoring_notification_channel.
      source  = "hashicorp/google"
      version = ">= 7.19.0"
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

# Read the archive file content during plan time (only for Cloud Functions)
# This data source reads the zip created by archive_file and embeds the content in the plan binary
# This ensures the content is available during apply even when running on a separate machine
data "local_sensitive_file" "function_archive_content" {
  count = var.execution_type == "function" ? 1 : 0

  filename   = data.archive_file.function_archive[0].output_path
  depends_on = [data.archive_file.function_archive]
}

# Write the embedded zip content to a file
# This recreates the zip file using the content embedded in the tfplan binary
# This supports running an `apply` after a `plan` on a different machine.
resource "local_file" "function_archive_for_upload" {
  count = var.execution_type == "function" ? 1 : 0

  filename        = "${path.module}/${var.job_name}-function.zip"
  content_base64  = data.local_sensitive_file.function_archive_content[0].content_base64
  file_permission = "0644"
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
  source = local_file.function_archive_for_upload[0].filename
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

  # Ensure service account and secret access are created before the function
  depends_on = [
    google_service_account.function_sa,
    google_secret_manager_secret_iam_member.function_secret_access
  ]

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

  # Ensure service account and secret access are created before the job
  depends_on = [
    google_service_account.function_sa,
    google_secret_manager_secret_iam_member.function_secret_access
  ]

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

      max_retries     = var.retries_enabled ? 3 : 0
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
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${var.job_name}:run"

    oauth_token {
      service_account_email = google_service_account.function_sa.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}

# Alerting resources (only created when enable_alerting is true)

# Read the Slack API token ephemerally: the value is available to this run at
# plan/apply time but is never persisted to Terraform state or saved plan
# files. A regular data source would store its full response, including
# secret_data, in both; that is how this token was exposed by the
# committed-tfplan incident.
ephemeral "google_secret_manager_secret_version" "slack_token" {
  count = var.enable_alerting ? 1 : 0

  project = "khan-academy"
  secret  = "Slack__API_token_for_alertlib"
}

locals {
  alert_project_id = var.alert_project_id != null ? var.alert_project_id : var.project_id
  slack_cc_mention = length(var.slack_mention_users) > 0 ? "\n\nCC: ${join(" ", var.slack_mention_users)}" : ""
  
  # Console URLs for functions and jobs
  function_console_url = "https://console.cloud.google.com/run/detail/${var.region}/${var.job_name}/observability/logs?project=${var.project_id}"
  job_console_url      = "https://console.cloud.google.com/run/jobs/detail/${var.region}/${var.job_name}/observability/logs?project=${var.project_id}"
}

# Monitoring notification channel for Slack
resource "google_monitoring_notification_channel" "slack_channel" {
  count = var.enable_alerting ? 1 : 0

  project      = local.alert_project_id
  display_name = "${var.job_name} Slack Alerts"
  type         = "slack"

  labels = {
    channel_name = var.slack_channel
  }

  sensitive_labels {
    # Write-only: the token is sent to the Monitoring API but never stored in
    # Terraform state or plan files. The ephemeral read above re-resolves the
    # latest secret version on each run; the _wo_version counter controls
    # when the API value is actually rewritten, so bump slack_token_rotation
    # after rotating the secret.
    auth_token_wo         = ephemeral.google_secret_manager_secret_version.slack_token[0].secret_data
    auth_token_wo_version = var.slack_token_rotation
  }
}

# Monitoring policy for Cloud Function failures (when execution_type is "function")
resource "google_monitoring_alert_policy" "function_failure" {
  count = var.enable_alerting && var.execution_type == "function" ? 1 : 0

  project      = local.alert_project_id
  display_name = "${var.job_name} Function Failure Alert"
  combiner     = "OR"
  enabled      = true

  alert_strategy {
    auto_close = "86400s" # Auto-close after 24 hours if condition is no longer met
  }

  conditions {
    display_name = "${var.job_name} function execution failure"

    condition_threshold {
      filter = "resource.type=\"cloud_function\" AND resource.labels.function_name=\"${var.job_name}\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status!=\"ok\""

      comparison      = "COMPARISON_GT"
      threshold_value = 0

      duration = "60s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        group_by_fields      = ["resource.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack_channel[0].name]

  documentation {
    content   = "The Cloud Function ${var.job_name} has failed to execute. Check the function logs for more details.\n\n[View Function in Console](${local.function_console_url})${local.slack_cc_mention}"
    mime_type = "text/markdown"
  }
}

# Monitoring policy for Cloud Run Job failures (when execution_type is "job")
resource "google_monitoring_alert_policy" "job_failure" {
  count = var.enable_alerting && var.execution_type == "job" ? 1 : 0

  project      = local.alert_project_id
  display_name = "${var.job_name} Job Failure Alert"
  combiner     = "OR"
  enabled      = true

  alert_strategy {
    auto_close = "86400s" # Auto-close after 24 hours if condition is no longer met
  }

  conditions {
    display_name = "${var.job_name} job execution failure"

    condition_threshold {
      filter = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"${var.job_name}\" AND metric.type=\"run.googleapis.com/job/completed_execution_count\" AND metric.labels.result!=\"succeeded\""

      comparison      = "COMPARISON_GT"
      threshold_value = 0

      duration = "60s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        group_by_fields      = ["resource.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack_channel[0].name]

  documentation {
    content   = "The Cloud Run Job ${var.job_name} has failed to execute or complete successfully. Check the job logs for more details.\n\n[View Job in Console](${local.job_console_url})${local.slack_cc_mention}"
    mime_type = "text/markdown"
  }
}
