# Local Airflow and PostgreSQL

These Terraform stacks install Apache Airflow and its PostgreSQL database into
separate namespaces of an existing local Kubernetes cluster. The Airflow stack
is in `infra/local`; the PostgreSQL-only stack is in `infra/local/postgresql`.
Neither stack creates a cluster or uses GCP resources.

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

Apply PostgreSQL first, then Airflow, from the repository root:

```bash
terraform -chdir=infra/local/postgresql init
terraform -chdir=infra/local/postgresql apply
terraform -chdir=infra/local init
terraform -chdir=infra/local apply
```

Both stacks prompt for the same `postgres_password`: at least 6 characters,
using only letters, digits, and `#$%_`, with at least one uppercase letter,
lowercase letter, digit, and allowed symbol. It is marked sensitive in
Terraform output, but is stored in local Terraform state and the Kubernetes
Secret. Keep both state files private and do not commit them.

To select a kubeconfig explicitly:

```bash
terraform -chdir=infra/local/postgresql apply \
  -var='kubeconfig_path=/path/to/config' \
  -var='kube_context=my-local-context'
terraform -chdir=infra/local apply \
  -var='kubeconfig_path=/path/to/config' \
  -var='kube_context=my-local-context'
```

If the previous `infra/local` Terraform state already manages PostgreSQL,
move those resources into the new PostgreSQL state before applying either
stack. Follow the existing-state migration steps in
[the PostgreSQL stack README](./postgresql/README.md).

The PostgreSQL service is available inside the cluster at
`airflow-postgresql.db-services.svc.cluster.local:5432`. The PostgreSQL
container uses an `emptyDir` volume, so its data is lost if the pod is
recreated. This keeps the local setup independent of a cluster storage
provisioner; use a persistent volume for any data that must survive pod
replacement.

Check the installation with:

```bash
kubectl -n db-services get deployments,pods,services
kubectl -n airflow get pods
```

## Open the Airflow UI from the host

The API server remains an internal `ClusterIP` service. To make
`http://localhost:8080` available automatically on a Linux host, install the
provided user-level systemd service. First make sure the host kubeconfig at
`~/.kube/config-microk8s-container.yaml` can access the cluster and `kubectl`
is available on the standard executable search path. If you previously applied
a NodePort configuration, apply the local Terraform stack again to restore the
internal service type (use the same variables as for the original apply):

```bash
terraform -chdir=infra/local apply
```

```bash
mkdir -p ~/.config/systemd/user
cp infra/local/airflow-port-forward.service \
  ~/.config/systemd/user/airflow-port-forward.service
systemctl --user daemon-reload
systemctl --user enable --now airflow-port-forward.service
```

The unit binds only to the host's loopback interface. Open
<http://localhost:8080> after starting it. The service retries if the cluster
or Airflow is temporarily unavailable.

Check status and logs with:

```bash
systemctl --user status airflow-port-forward.service
journalctl --user -u airflow-port-forward.service -f
```

The service starts when your user session starts. To also start it at boot
before you log in, enable lingering for your user (may require administrator
permission):

```bash
loginctl enable-linger "$USER"
```

To stop and disable automatic forwarding:

```bash
systemctl --user disable --now airflow-port-forward.service
```

The local chart values disable the chart's bundled PostgreSQL and configure
Airflow to use the separately managed database. Airflow's user-creation and
database-migration hooks are disabled to avoid Terraform installation hanging.
The stacks are independent of the GKE dev/prod stacks. Destroy Airflow from
`infra/local` before destroying PostgreSQL from `infra/local/postgresql`.
