# Data Transformation Platform (Reference Implementation)

Weekend-scoped reference implementation of the plan in
[`../Weekend-Project-GKE_AirFlow.md`](../Weekend-Project-GKE_AirFlow.md):
a multi-domain BigQuery transformation platform, orchestrated by
**self-hosted Apache Airflow on GKE Autopilot**, deployed via Terraform +
GitHub Actions (keyless, Workload Identity Federation), with dbt (via
astronomer-cosmos) doing the SQL transformation work and Pub/Sub carrying
cross-domain "data product released" events.

See the plan document for the full narrative, rationale, and the
Cloud Composer / Eventarc alternatives. This folder is the *scaffold*
that plan describes, ready to be filled in and deployed.

## Layout

```
.github/workflows/   CI/CD: terraform plan/apply, dbt Slim CI, deploy to GKE
infra/
  bootstrap/         One-time: WIF pool/provider + CI service accounts (applied manually)
  modules/           Reusable Terraform modules (bigquery_domain, airflow_gke, data_product_topic, domain_identity, composer)
  envs/{dev,prd}/    Environment composition - reads domains/*/domain.yaml and wires modules
domains/
  sales/             Autonomous domain unit: dbt project + DAGs + domain.yaml contract
  finance/           Consumes sales.fct_orders via BigQuery source() + Pub/Sub event
platform/
  dags_common/       Shared Airflow plugin code (Cosmos DAG factory, release publisher, freshness guard)
  docker/airflow/    Custom Airflow image (base + cosmos + dbt-bigquery)
  helm/airflow/      Helm values per environment
  scripts/           deploy + domain-manifest validation scripts
```

## Quick start

1. **Bootstrap (one-time, local):** follow Phase 1 of the plan — create projects,
   enable APIs, create the `dtp-ref-tfstate` GCS bucket, then:
   ```bash
   cd infra/bootstrap
   terraform init
   terraform apply
   ```
   Copy the outputs into GitHub Actions repo secrets (`WIF_PROVIDER`, `SA_TF_PLAN`,
   `SA_TF_APPLY`, `SA_DBT_CI`, `SA_DEPLOY`).

2. **Provision an environment:**
   ```bash
   cd infra/envs/dev
   terraform init
   terraform apply
   ```
   This creates the GKE Autopilot cluster, Cloud SQL metadata DB, BigQuery
   datasets per domain, and the Pub/Sub data-product topics — see
   `modules/airflow_gke`, `modules/bigquery_domain`, `modules/data_product_topic`.

3. **Build dbt locally** (validates BigQuery access before you rely on CI):
   ```bash
   cd domains/sales/dbt && dbt deps && dbt build --target dev
   cd domains/finance/dbt && dbt deps && dbt build --target dev
   ```

4. **Push to `main`** — `cd-deploy.yml` builds the Airflow image, pushes it,
   and runs `helm upgrade` against the cluster Terraform created.

5. **Teardown (Sunday night):**
   ```bash
   cd infra/envs/prd && terraform destroy
   cd infra/envs/dev && terraform destroy
   ```
   Keep `infra/bootstrap` and the state bucket — see Phase 10 of the plan.

## Conventions enforced here

- A domain may only `source()` another domain's `mart` dataset, never `ref()`
  across domains — see `domains/finance/dbt/models/staging/_sources.yml`.
- `domains/<name>/domain.yaml` is the single source of truth for schedule,
  produced data products, and consumed upstream products. Both Terraform
  (`infra/envs/*/main.tf`) and CI (`platform/scripts/validate_domain_manifest.py`)
  read it.
- Everything is provisioned centrally today via the `domain.yaml` for-each
  loop in `infra/envs/<env>/main.tf`. Each domain's own `infra.tf` is *not*
  wired into that graph — it documents the standalone Terraform the domain
  will run after Phase 9 extraction into its own repo. See the comment at
  the top of `domains/sales/infra.tf`.

## Gaps filled beyond the plan

The plan's code snippets are illustrative, not a complete repo — a few
pieces were referenced but never fully specified. These were added to make
the scaffold internally consistent and actually runnable:

- **`validate_freshness` + the `_dtp_processed_events` dedup table** (Step
  5.5 described these but never defined them) — implemented in
  `platform/dags_common/freshness.py`, backed by a shared `dtp_platform`
  BigQuery dataset created once in `infra/envs/*/main.tf`.
- **DLQ topic + Pub/Sub IAM bindings** (`google_pubsub_topic.dlq` was
  referenced but never created) — added to `infra/modules/data_product_topic`,
  along with a `dlq_triage` subscription (`dlq_retention_duration`, default 14
  days) so dead-lettered messages are actually pullable/inspectable instead of
  vanishing instantly — a DLQ topic with zero subscriptions holds nothing at
  all, it doesn't accumulate "forever" either. A `google_monitoring_alert_policy`
  fires when `num_undelivered_messages > 0` on that subscription; wire a real
  destination via `dlq_alert_notification_channels` (empty by default — the
  alert still raises an incident in Cloud Monitoring either way, it just won't
  page/email/Slack anyone until channels are supplied). Requires adding
  `monitoring.googleapis.com` to the Step 1.2 API-enablement list.
- **`domain_identity` module** — only referenced by interface in the plan,
  so it was built from scratch (per-domain service account +
  `bigquery.jobUser`).
- **Cloud SQL Auth Proxy sidecar** — the Helm values said `host: 127.0.0.1`
  with no container behind it; added `extraContainers` to
  `platform/helm/airflow/values-{dev,prd}.yaml`.
- **`domains/*/infra.tf`** — documented as *not* wired into the live
  Terraform graph (it would otherwise duplicate what `infra/envs/*/main.tf`'s
  `domain.yaml` for-each loop already provisions). It's what each domain
  becomes standalone with after the Phase 9 repo-extraction split — see the
  header comment in `domains/sales/infra.tf`.
- **`fct_revenue`** — sales' `fct_orders` didn't carry any monetary column,
  so "revenue" would have been meaningless; added an `order_items`/
  `sale_price` join through `stg_order_items.sql` so finance aggregates a
  real `order_value`.
- One genuine bug caught via linting: `ci-dbt.yml` had unquoted `${{ }}`
  inside flow-mapping YAML (`{ }`) syntax, which is invalid YAML — fixed by
  quoting both occurrences.

> **Editor note:** you may see "Property X is not allowed" warnings on the
> dbt YAML files (`dbt_project.yml`, `_sources.yml`, `_schema.yml`). These
> are false positives from the VS Code dbt extension's schema validator,
> which reports "dbt not found" — i.e. it's validating without a real dbt
> environment. The flagged keys (`partition_by`, `sources[].project/dataset`,
> `relationships.to/field`, `loaded_at_field`/`freshness`) are all standard,
> correct dbt-bigquery configuration.
