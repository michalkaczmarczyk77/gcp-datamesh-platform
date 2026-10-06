# Map these five outputs to the GitHub Actions repo secrets consumed by
# .github/workflows/{ci-terraform,ci-dbt,cd-deploy}.yml (Phase 7 / Step 3).

output "wif_provider" {
  value = "projects/${var.project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
  description = "-> secrets.WIF_PROVIDER"
}

output "sa_tf_plan_email" {
  value       = google_service_account.tf_plan.email
  description = "-> secrets.SA_TF_PLAN"
}

output "sa_tf_apply_email" {
  value       = google_service_account.tf_apply.email
  description = "-> secrets.SA_TF_APPLY"
}

output "sa_dbt_ci_email" {
  value       = google_service_account.dbt_ci.email
  description = "-> secrets.SA_DBT_CI"
}

output "sa_deploy_email" {
  value       = google_service_account.deploy.email
  description = "-> secrets.SA_DEPLOY"
}
