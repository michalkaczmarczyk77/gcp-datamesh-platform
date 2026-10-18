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

The chart exposes Airflow through an internal `ClusterIP` service named
`airflow-api-server` on port `8080`. This is intentional: a `ClusterIP` is not
directly reachable from the host, but `kubectl port-forward` provides a local
connection without exposing the UI to the network.

Run this from a terminal on the host machine, using the kubeconfig and context
that can reach the local cluster:

```bash
kubectl --kubeconfig="$HOME/.kube/config-microk8s-container.yaml" \
  -n airflow port-forward svc/airflow-api-server 8080:8080
```

Keep the command running and open <http://localhost:8080> in a browser. Stop
the port-forward with `Ctrl+C`. If `kubectl` already uses the correct
kubeconfig and context, omit `--kubeconfig=...`.

If you run the command inside the devcontainer instead, the forwarded
`localhost` port belongs to the container; use VS Code's forwarded-ports
control to open port `8080` on the host, or run `kubectl port-forward` directly
from the host as above. No Terraform or Helm service change is needed for
host-only access. Avoid changing the service to `NodePort` or `LoadBalancer`
unless you specifically need network-wide access and have secured that access.

The local chart values disable the chart's bundled PostgreSQL and configure
Airflow to use the separately managed database. Airflow's user-creation and
database-migration hooks are disabled to avoid Terraform installation hanging.
The stacks are independent of the GKE dev/prod stacks. Destroy Airflow from
`infra/local` before destroying PostgreSQL from `infra/local/postgresql`.

# Run Airflow WebUi

Forward ports and expose it outside cluster

```bash
nohup kubectl --kubeconfig="$HOME/.kube/config-microk8s-container.yaml" \
  -n airflow port-forward svc/airflow-api-server 8080:8080 \
  > "$HOME/airflow-port-forward.log" 2>&1 < /dev/null &
echo $! > "$HOME/airflow-port-forward.pid"

```

- Open http://localhost:8080. 
- Login as default admin/admin

To check the log:

```bash
tail -f "$HOME/airflow-port-forward.log"
```

To stop it, terminate the saved process:

```bash
kill "$(cat "$HOME/airflow-port-forward.pid")"
rm "$HOME/airflow-port-forward.pid"
```
