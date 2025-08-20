# GitHub Terraform CI Bootstrap Module
# This module creates the necessary infrastructure for managing Terraform in GitHub Actions CI
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

# Define service-to-role mapping
locals {
  service_roles = {
    cloudfunctions = "roles/cloudfunctions.admin"
    storage        = "roles/storage.admin"
    pubsub         = "roles/pubsub.admin"
    scheduler      = "roles/cloudscheduler.admin"
    run            = "roles/run.admin"
    cloudbuild     = "roles/cloudbuild.builds.builder"
  }

  # Parse GitHub repository into org and repo name
  github_org  = split("/", var.github_repository)[0]
  github_repo = split("/", var.github_repository)[1]

  # Compute default bucket name: terraform-{org}-{repo}-{service} (normalized for GCS bucket naming rules)
  # GCS bucket names: lowercase letters, numbers, hyphens only (no underscores)
  default_bucket_name = replace("terraform-${lower(local.github_org)}-${lower(local.github_repo)}-${lower(var.service_name)}", "_", "-")

  # Use provided bucket name or computed default
  terraform_state_bucket = coalesce(var.terraform_state_bucket, local.default_bucket_name)

  # Flatten target_projects into individual service permissions
  project_service_permissions = flatten([
    for project_id, config in var.target_projects : [
      for service in config.required_services : {
        key        = "${project_id}-${service}"
        project_id = project_id
        service    = service
        role       = local.service_roles[service]
      }
    ]
  ])
}

# Service account for GitHub Actions (always created in khan-internal-services)
resource "google_service_account" "github_ci" {
  account_id   = "${var.service_name}-ci"
  display_name = "GitHub CI for ${var.service_name}"
  project      = "khan-internal-services"
}

# === CROSS-PROJECT PERMISSIONS ===

# Service-specific permissions across target projects
resource "google_project_iam_member" "ci_service_permissions" {
  for_each = {
    for perm in local.project_service_permissions : perm.key => perm
  }

  project = each.value.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# Cloud Functions requires service account user role
resource "google_project_iam_member" "ci_sa_user" {
  for_each = {
    for project_id, config in var.target_projects : project_id => config
    if contains(config.required_services, "cloudfunctions")
  }

  project = each.key
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# Allow creating and deleting service accounts (needed for Terraform)
resource "google_project_iam_member" "ci_sa_admin" {
  for_each = var.target_projects

  project = each.key
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# Allow creating IAM bindings (e.g. google_project_iam_member)
resource "google_project_iam_member" "ci_iam_admin" {
  for_each = var.target_projects

  project = each.key
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.github_ci.email}"
}

# === TERRAFORM STATE BUCKET ACCESS ===

# Access to Terraform state bucket
resource "google_storage_bucket_iam_member" "ci_state_bucket_access" {
  bucket = local.terraform_state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_ci.email}"
}

resource "google_storage_bucket_iam_member" "ci_state_bucket_reader" {
  bucket = local.terraform_state_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.github_ci.email}"
}

resource "google_storage_bucket_iam_member" "ci_storage_legacy_bucket_owner" {
  bucket = local.terraform_state_bucket
  role   = "roles/storage.legacyBucketOwner"
  member = "serviceAccount:${google_service_account.github_ci.email}"
}

# === SECRET MANAGER ===

# Allow reading secret metadata (needed for data.google_secret_manager_secret_version)
resource "google_project_iam_member" "ci_secretmanager_viewer" {
  count   = length(var.secret_ids) > 0 ? 1 : 0
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

# Get khan-internal-services project information to retrieve the numeric project ID
data "google_project" "khan_internal_services" {
  project_id = "khan-internal-services"
}

# Shared Workload Identity Pool for all GitHub CI
# This will be created by the first module invocation and reused by subsequent ones
resource "google_iam_workload_identity_pool" "github_ci_pool" {
  provider                  = google
  project                   = data.google_project.khan_internal_services.number
  workload_identity_pool_id = "khan-internal-services-github-ci"
  display_name              = "Khan GitHub CI Pool"

  lifecycle {
    # Prevent deletion if other services are still using this pool
    prevent_destroy = true
  }
}

# Workload Identity Provider for this specific service
resource "google_iam_workload_identity_pool_provider" "github_ci_provider" {
  provider                           = google
  project                            = data.google_project.khan_internal_services.number
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.service_name}-provider"
  display_name                       = substr("${var.service_name} GitHub", 0, 32)
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
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.khan_internal_services.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/attribute.repository/${var.github_repository}"
}
