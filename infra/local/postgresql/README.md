# Local PostgreSQL stack

This Terraform root manages the `db-services` namespace and the PostgreSQL
Secret, Deployment, and ClusterIP Service used by the local Airflow stack.
The database service is available at
`airflow-postgresql.db-services.svc.cluster.local:5432`.

The PostgreSQL pod uses an `emptyDir` volume, so its data is lost if the pod is
recreated. Use a persistent volume if the data must survive pod replacement.
The `postgres_password` variable must be at least 6 characters, use only
letters, digits, and `#$%_`, and include at least one uppercase letter,
lowercase letter, digit, and allowed symbol. It is stored in this stack's
local Terraform state and the Kubernetes Secret; keep the state file private
and do not commit it.

## Fresh install

From the repository root, install PostgreSQL before applying the Airflow
stack:

```bash
terraform -chdir=infra/local/postgresql init
terraform -chdir=infra/local/postgresql apply
terraform -chdir=infra/local init
terraform -chdir=infra/local apply
```

Supply the same `postgres_password`, `kubeconfig_path`, and `kube_context`
values to both stacks as needed. The Kubernetes provider defaults to
`~/.kube/config-microk8s-container.yaml`.

## Existing `infra/local` state

If the existing `infra/local` state already manages PostgreSQL, move those
resources to this stack's state before applying either configuration. From
`infra/local`, back up the existing state files, initialize the new stack,
and move the existing resource addresses into its state:

```bash
terraform -chdir=postgresql init
terraform state mv -state-out=postgresql/terraform.tfstate \
  kubernetes_namespace_v1.airflow kubernetes_namespace_v1.postgresql
terraform state mv -state-out=postgresql/terraform.tfstate \
  kubernetes_secret_v1.postgresql kubernetes_secret_v1.postgresql
terraform state mv -state-out=postgresql/terraform.tfstate \
  kubernetes_deployment_v1.postgresql kubernetes_deployment_v1.postgresql
terraform state mv -state-out=postgresql/terraform.tfstate \
  kubernetes_service_v1.postgresql kubernetes_service_v1.postgresql
```

Review plans in both directories before applying. The existing namespace must
be `db-services` for this state move to preserve it; if it has a different
name, reconcile the namespace before applying to avoid replacing it. The
Airflow stack now manages a separate `airflow` namespace and connects to the
PostgreSQL Service in `db-services`.
