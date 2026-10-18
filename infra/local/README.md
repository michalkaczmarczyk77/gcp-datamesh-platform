# Local Airflow installation

This Terraform stack installs the Apache Airflow Helm chart and a separate
PostgreSQL pod into the `airflow` namespace of an existing local Kubernetes
cluster. It does not create a cluster or use GCP resources.

## Prerequisites

- Terraform 1.9 or later
- Helm provider access to the Apache Airflow chart repository
- A reachable Kubernetes cluster and a kubeconfig available through
  `KUBECONFIG` or `~/.kube/config`

The Kubernetes cluster runs outside the devcontainer at `192.168.0.102`. The
local Terraform providers default to the host file
`~/.kube/config-microk8s-container.yaml`, which the devcontainer bind-mounts as
`/root/.kube/config-microk8s-container.yaml`. The kubeconfig `server` entry
must use an address and port reachable from wherever Terraform is running,
not `127.0.0.1` or `localhost`. For MicroK8s, the API server normally listens
on port `16443`.

If the kubeconfig still points to localhost, update its cluster endpoint on
the host before running Terraform. This preserves the existing credentials
and certificate data:

```bash
KUBECONFIG="$HOME/.kube/config-microk8s-container.yaml"
CLUSTER="$(kubectl config view --kubeconfig="$KUBECONFIG" \
  -o jsonpath='{.clusters[0].name}')"
kubectl config set-cluster "$CLUSTER" \
  --server=https://192.168.0.102:16443 \
  --kubeconfig="$KUBECONFIG"
```

Use the cluster's actual API port if it is not MicroK8s. The API server must
allow connections from the machine running Terraform, and its TLS certificate
must be valid for `192.168.0.102`; do not disable certificate verification.
Check connectivity from the same environment where you will run Terraform:

```bash
kubectl get nodes
```

If the cluster uses a different kubeconfig file or context, set
`kubeconfig_path` and/or `kube_context` as shown below.

## Install

From the repository root:

```bash
cd infra/local
terraform init
terraform apply
```

Terraform prompts for `postgres_password`; use a value of at least 16
characters. It is marked sensitive in Terraform output, but is stored in the
local Terraform state and Kubernetes Secret. Keep the state file private and
do not commit it.

To select a kubeconfig explicitly:

```bash
terraform apply \
  -var='kubeconfig_path=/path/to/config' \
  -var='kube_context=my-local-context'
```

The PostgreSQL service is available inside the cluster at
`airflow-postgresql.airflow.svc.cluster.local:5432`. The PostgreSQL container
uses an `emptyDir` volume, so its data is lost if the pod is recreated. This
keeps the local setup independent of a cluster storage provisioner; use a
persistent volume for any data that must survive pod replacement.

Check the installation with:

```bash
kubectl -n airflow get deployments,pods,services
```

The local chart values disable the chart's bundled PostgreSQL and configure
Airflow to use the separately managed database. Airflow's user-creation and
database-migration hooks are disabled to avoid Terraform installation hanging.
The release is independent of the GKE dev/prod stacks and can be removed with
`terraform destroy` from `infra/local`.
