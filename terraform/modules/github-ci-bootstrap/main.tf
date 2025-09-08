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
  read_write_roles = {
    cloudfunctions   = "roles/cloudfunctions.admin"
    storage          = "roles/storage.admin"
    pubsub           = "roles/pubsub.admin"
    scheduler        = "roles/cloudscheduler.admin"
    run              = "roles/run.admin"
    cloudbuild       = "roles/cloudbuild.admin"
    artifactregistry = "roles/artifactregistry.admin"
    secretmanager    = "roles/secretmanager.admin"
    logging          = "roles/logging.admin"
    monitoring       = "roles/monitoring.admin"
  }

  # Read-only roles for any branch
  read_only_roles = {
    cloudfunctions   = "roles/cloudfunctions.viewer"
    storage          = "roles/storage.objectViewer"
    pubsub           = "roles/pubsub.viewer"
    scheduler        = "roles/cloudscheduler.viewer"
    run              = "roles/run.viewer"
    cloudbuild       = "roles/cloudbuild.builds.builder" # Read-only branches still need build access
    artifactregistry = "roles/artifactregistry.reader"
    secretmanager    = "roles/secretmanager.viewer"
    logging          = "roles/logging.viewer"
    monitoring       = "roles/monitoring.viewer"
  }

  # Parse GitHub repository into org and repo name
  github_org  = split("/", var.github_repository)[0]
  github_repo = split("/", var.github_repository)[1]

  # Compute default bucket name: terraform-{org}-{repo}-{service} (normalized for GCS bucket naming rules)
  # GCS bucket names: lowercase letters, numbers, hyphens only (no underscores)
  default_bucket_name = replace("terraform-${lower(local.github_org)}-${lower(local.github_repo)}-${lower(var.service_name)}", "_", "-")

  # Use provided bucket name or computed default
  terraform_state_bucket = coalesce(var.terraform_state_bucket, local.default_bucket_name)

  # Flatten target_projects into individual service permissions for read-write access
  project_service_permissions_rw = flatten([
    for project_id, config in var.target_projects : [
      for service in config.required_services : {
        key        = "${project_id}-${service}-rw"
        project_id = project_id
        service    = service
        role       = local.read_write_roles[service]
      }
    ]
  ])

  # Flatten target_projects into individual service permissions for read-only access
  project_service_permissions_ro = flatten([
    for project_id, config in var.target_projects : [
      for service in config.required_services : {
        key        = "${project_id}-${service}-ro"
        project_id = project_id
        service    = service
        role       = local.read_only_roles[service]
      }
    ]
  ])
}

# Service account for GitHub Actions write-enabled branches (always created in khan-internal-services)
resource "google_service_account" "github_ci_rw" {
  account_id   = "${var.service_name}-ci-rw"
  display_name = "GitHub CI for ${var.service_name} (read-write)"
  project      = "khan-internal-services"
}

# Service account for GitHub Actions read-only access (available to any branch)
resource "google_service_account" "github_ci_ro" {
  account_id   = "${var.service_name}-ci-ro"
  display_name = "GitHub CI for ${var.service_name} (read-only)"
  project      = "khan-internal-services"
}

# === CROSS-PROJECT PERMISSIONS ===

# Service-specific permissions across target projects (read-write access)
resource "google_project_iam_member" "ci_service_permissions_rw" {
  for_each = {
    for perm in local.project_service_permissions_rw : perm.key => perm
  }

  project = each.value.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.github_ci_rw.email}"
}

# Service-specific permissions across target projects (read-only access)
resource "google_project_iam_member" "ci_service_permissions_ro" {
  for_each = {
    for perm in local.project_service_permissions_ro : perm.key => perm
  }

  project = each.value.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.github_ci_ro.email}"
}

# Cloud Functions requires service account user role (read-write access)
resource "google_project_iam_member" "ci_sa_user_rw" {
  for_each = {
    for project_id, config in var.target_projects : project_id => config
    if contains(config.required_services, "cloudfunctions")
  }

  project = each.key
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_ci_rw.email}"
}

# Cloud Functions requires service account user role (read-only access - no service account user needed)
# Note: Read-only access doesn't need service account user role since it can't create/delete service accounts

# Allow creating and deleting service accounts (needed for Terraform - read-write access only)
resource "google_project_iam_member" "ci_sa_admin_rw" {
  for_each = var.target_projects

  project = each.key
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.github_ci_rw.email}"
}

# Allow reading service accounts (needed for Terraform - read-only access)
resource "google_project_iam_member" "ci_sa_viewer_ro" {
  for_each = var.target_projects

  project = each.key
  role    = "roles/iam.serviceAccountViewer"
  member  = "serviceAccount:${google_service_account.github_ci_ro.email}"
}

# Allow reading project information and IAM policies (needed for Terraform - read-only access)
resource "google_project_iam_member" "ci_project_viewer_ro" {
  for_each = var.target_projects

  project = each.key
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.github_ci_ro.email}"
}

# Allow creating IAM bindings (e.g. google_project_iam_member - read-write access only)
resource "google_project_iam_member" "ci_iam_admin_rw" {
  for_each = var.target_projects

  project = each.key
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.github_ci_rw.email}"
}

# === TERRAFORM STATE BUCKET ACCESS ===

# Access to Terraform state bucket (read-write access - full access)
resource "google_storage_bucket_iam_member" "ci_state_bucket_access_rw" {
  bucket = local.terraform_state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_ci_rw.email}"
}

resource "google_storage_bucket_iam_member" "ci_storage_legacy_bucket_owner_rw" {
  bucket = local.terraform_state_bucket
  role   = "roles/storage.legacyBucketOwner"
  member = "serviceAccount:${google_service_account.github_ci_rw.email}"
}

# Access to Terraform state bucket (read-only access)
resource "google_storage_bucket_iam_member" "ci_state_bucket_reader_ro" {
  bucket = local.terraform_state_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.github_ci_ro.email}"
}

resource "google_storage_bucket_iam_member" "ci_state_bucket_legacy_reader_ro" {
  bucket = local.terraform_state_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.github_ci_ro.email}"
}

# === SECRET MANAGER ===

# Dynamic secret admin access based on provided secret IDs (read-write access)
resource "google_secret_manager_secret_iam_member" "ci_secret_admin_rw" {
  for_each  = toset(var.secret_ids)
  project   = var.secrets_project_id
  secret_id = each.value
  role      = "roles/secretmanager.admin"
  member    = "serviceAccount:${google_service_account.github_ci_rw.email}"
}

# Dynamic secret accessor access for read-only access
resource "google_secret_manager_secret_iam_member" "ci_secret_accessor_ro" {
  for_each  = toset(var.secret_ids)
  project   = var.secrets_project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_ci_ro.email}"
}

# Allow reading secret IAM policies (needed for Terraform - read-only access)
resource "google_secret_manager_secret_iam_member" "ci_secret_viewer_ro" {
  for_each  = toset(var.secret_ids)
  project   = var.secrets_project_id
  secret_id = each.value
  role      = "roles/secretmanager.viewer"
  member    = "serviceAccount:${google_service_account.github_ci_ro.email}"
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

# Workload Identity Provider for read-write branches
resource "google_iam_workload_identity_pool_provider" "github_ci_provider_rw" {
  provider                  = google
  project                   = data.google_project.khan_internal_services.number
  workload_identity_pool_id = google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id
  # There's a max length of 32 characters for the workload identity pool provider ID
  # In order to prevent name collisions, we use the SHA256 hash of the service name
  workload_identity_pool_provider_id = "${substr(sha256(var.service_name), 0, 8)}-rw"
  display_name                       = substr("${var.service_name} GitHub (read/write)", 0, 32)
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  attribute_condition = "attribute.repository == \"${var.github_repository}\" && (${join(" || ", [for pattern in var.write_branch_patterns : "attribute.ref == \"refs/heads/${pattern}\""])})"
}

# Workload Identity Provider for read-only access
resource "google_iam_workload_identity_pool_provider" "github_ci_provider_ro" {
  provider                  = google
  project                   = data.google_project.khan_internal_services.number
  workload_identity_pool_id = google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id
  # There's a max length of 32 characters for the workload identity pool provider ID
  # In order to prevent name collisions, we use the SHA256 hash of the service name
  workload_identity_pool_provider_id = "${substr(sha256(var.service_name), 0, 8)}-ro"
  display_name                       = substr("${var.service_name} GitHub (read-only)", 0, 32)
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  attribute_condition = "attribute.repository == \"${var.github_repository}\""
}

# Bind the read-write service account to the Workload Identity provider
resource "google_service_account_iam_member" "github_ci_identity_binding_rw" {
  service_account_id = google_service_account.github_ci_rw.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.khan_internal_services.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/attribute.repository/${var.github_repository}"
}

# Bind the read-only service account to the Workload Identity provider
resource "google_service_account_iam_member" "github_ci_identity_binding_ro" {
  service_account_id = google_service_account.github_ci_ro.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.khan_internal_services.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_ci_pool.workload_identity_pool_id}/attribute.repository/${var.github_repository}"
}
