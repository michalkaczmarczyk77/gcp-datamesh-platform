# Phase 1 / Step 1.4 — Workload Identity Federation for GitHub Actions.
# Applied once, locally, before any GitHub Actions workflow can run.

# 
# Configuring OpenID Connect in Google Cloud Platform
# https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-google-cloud-platform
# 

# IAM Principal: principal://iam.googleapis.com/projects/571278907342/locations/global/workloadIdentityPools/dtp-github-pool/subject/SUBJECT_ATTRIBUTE_VALUE
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool
  display_name              = "Data Platform GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_pool_github_provider

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Hard requirement: without attribute_condition the pool accepts ANY GitHub repo.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}

# --- Service accounts used by the three GitHub Actions workflows -----------
# tf_plan/tf_apply -> ci-terraform.yml, dbt_ci -> ci-dbt.yml, deploy -> cd-deploy.yml

resource "google_service_account" "tf_plan" {
  project      = var.project_id
  account_id   = "sa-tf-plan"
  display_name = "ci-terraform: plan on PRs"
}

resource "google_service_account" "tf_apply" {
  project      = var.project_id
  account_id   = "sa-tf-apply"
  display_name = "ci-terraform: apply on main"
}

resource "google_service_account" "dbt_ci" {
  project      = var.project_id
  account_id   = "sa-dbt-ci"
  display_name = "ci-dbt: Slim CI builds against ci_pr_<n> datasets"
}

resource "google_service_account" "deploy" {
  project      = var.project_id
  account_id   = "sa-deploy"
  display_name = "cd-deploy: build/push image, helm upgrade"
}

# --- WIF bindings: which repo/ref may impersonate which SA ------------------
# tf_apply/deploy are further restricted to refs/heads/main (least privilege,
# per the plan's "tighten later" note); tf_plan/dbt_ci run on PR branches too.

resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.tf_plan.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

resource "google_service_account_iam_member" "apply_wif" {
  service_account_id = google_service_account.tf_apply.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.ref/refs/heads/main"
}

resource "google_service_account_iam_member" "dbt_ci_wif" {
  service_account_id = google_service_account.dbt_ci.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

resource "google_service_account_iam_member" "deploy_wif" {
  service_account_id = google_service_account.deploy.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.ref/refs/heads/main"
}

# --- Least-privilege project roles -----------------------------------------

resource "google_project_iam_member" "plan_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.tf_plan.email}"
}

resource "google_project_iam_member" "apply_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.tf_apply.email}"
}

resource "google_project_iam_member" "apply_security_admin" {
  project = var.project_id
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${google_service_account.tf_apply.email}"
}

resource "google_project_iam_member" "dbt_ci_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.dbt_ci.email}"
}

resource "google_project_iam_member" "deploy_roles" {
  for_each = toset([
    "roles/container.developer",     # get-credentials + kubectl/helm against GKE
    "roles/artifactregistry.writer", # push the Airflow image
    "roles/storage.objectAdmin",     # publish dbt manifests to gs://dtp-ref-artifacts
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deploy.email}"
}
