# GitHub Actions CI/CD Bootstrap Module
# This module creates the necessary infrastructure for GitHub Actions to manage Terraform resources
# It follows the principle of least privilege and uses Workload Identity Federation

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

# Service account for GitHub Actions to use for Terraform operations
resource "google_service_account" "github_ci" {
  account_id   = "${var.project_name}-terraform-ci"
  display_name = "Terraform GitHub Actions Deploy Service Account for ${var.project_display_name}"
  project      = var.google_project_name
}

# === ROLES IN TARGET INFRASTRUCTURE PROJECT ===

# Deploy Cloud Functions
resource "google_project_iam_member" "ci_cloudfunctions_admin" {
  count   = contains(var.required_services, "cloudfunctions") ? 1 : 0
  project = var.google_project_name
  role    = "roles/cloudfunctions.admin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# Required to set service account in Cloud Function resources
resource "google_project_iam_member" "ci_sa_user" {
  count   = contains(var.required_services, "cloudfunctions") ? 1 : 0
  project = var.google_project_name
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# Allow creating and deleting service accounts
resource "google_project_iam_member" "ci_sa_admin" {
  project = var.google_project_name
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# Allow creating IAM bindings (e.g. google_project_iam_member)
resource "google_project_iam_member" "ci_iam_admin" {
  project = var.google_project_name
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# === STORAGE FOR FUNCTION CODE ===

# Allow managing storage buckets for function code
resource "google_project_iam_member" "ci_storage_admin" {
  count   = contains(var.required_services, "storage") ? 1 : 0
  project = var.google_project_name
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# === GCS BACKEND ===

# Access to Terraform state bucket
resource "google_storage_bucket_iam_member" "ci_state_bucket_access" {
  bucket = var.terraform_state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_ci.email}"
}

resource "google_storage_bucket_iam_member" "ci_state_bucket_reader" {
  bucket = var.terraform_state_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.github_ci.email}"
}

resource "google_storage_bucket_iam_member" "ci_storage_legacy_bucket_owner" {
  bucket = var.terraform_state_bucket
  role   = "roles/storage.legacyBucketOwner"
  member = "serviceAccount:${google_service_account.github_ci.email}"
}

# === PUBSUB FOR FUNCTION TRIGGERS ===

# Allow managing PubSub topics and subscriptions
resource "google_project_iam_member" "ci_pubsub_admin" {
  count   = contains(var.required_services, "pubsub") ? 1 : 0
  project = var.google_project_name
  role    = "roles/pubsub.admin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# === CLOUD SCHEDULER ===

# Allow managing Cloud Scheduler jobs
resource "google_project_iam_member" "ci_cloud_scheduler_admin" {
  count   = contains(var.required_services, "scheduler") ? 1 : 0
  project = var.google_project_name
  role    = "roles/cloudscheduler.admin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# === SECRET MANAGER ===

# Allow reading secret metadata (needed for data.google_secret_manager_secret_version)
resource "google_project_iam_member" "ci_secretmanager_viewer" {
  count   = var.secrets_project_id != null ? 1 : 0
  project = var.secrets_project_id
  role    = "roles/secretmanager.viewer"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# Dynamic secret access based on provided secret IDs
resource "google_secret_manager_secret_iam_member" "ci_secret_access" {
  for_each  = toset(var.secret_ids)
  project   = var.secrets_project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_ci.email}"
}

# === WORKLOAD IDENTITY FEDERATION FOR GITHUB CI ===

# Get current project information to retrieve the numeric project ID
data "google_project" "current" {
  project_id = var.google_project_name
}

# Workload Identity Pool for GitHub CI
resource "google_iam_workload_identity_pool" "github_ci_pool" {
  provider                  = google
  project                   = data.google_project.current.number
  workload_identity_pool_id = "${var.project_name}-github-ci-pool"
  display_name              = "${var.project_display_name} GitHub CI Pool"
}

# Workload Identity Provider for GitHub OIDC
resource "google_iam_workload_identity_pool_provider" "github_ci_provider" {
  provider                           = google
  project                            = data.google_project.current.number
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.project_name}-github-ci-provider"
  display_name                       = "${var.project_display_name} GitHub Provider"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  attribute_condition = "attribute.repository == \"${var.github_repository}\""
}

# Bind the service account to the Workload Identity provider
resource "google_service_account_iam_member" "github_ci_identity_binding" {
  service_account_id = google_service_account.github_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_ci_pool.name}/attribute.repository/${var.github_repository}"
}
