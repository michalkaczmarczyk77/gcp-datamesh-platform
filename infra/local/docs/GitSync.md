# Connecting local Airflow to a private Git repository

The local Airflow release uses the official Apache Airflow Helm chart (version
`1.22.0`). Its Git sync settings are in
[the local values file](../../platform/helm/airflow/values-local.yaml), and
Terraform applies those values from `infra/local`.

This guide uses an SSH deploy key. A dedicated, read-only deploy key is
preferable to a personal SSH key or a GitHub personal access token: it grants
access only to the repository Airflow needs.

## 1. Prepare a read-only SSH deploy key

Generate a key pair on a trusted machine. Use a new file name so you do not
overwrite an existing key; the unattended Git sync process requires a key
without a passphrase.

```bash
ssh-keygen -t ed25519 -N "" \
  -C "airflow-local-git-sync" \
  -f "$HOME/.ssh/airflow_git_sync"
```

In GitHub, open the private repository's **Settings → Deploy keys → Add deploy
key**. Copy the public key from:

```bash
cat "$HOME/.ssh/airflow_git_sync.pub"
```

Leave **Allow write access** unchecked. The public key can be registered in
GitHub; do not share or commit the private key (`airflow_git_sync`).

## 2. Create the Kubernetes Secret

The `airflow` namespace must already exist. The Terraform Airflow stack creates
it; on a new installation, install the local stack once before creating this
Secret.

Create or update the Secret from the private key:

```bash
kubectl -n airflow create secret generic airflow-ssh-secret \
  --from-file=id_ed25519="$HOME/.ssh/airflow_git_sync" \
  --dry-run=client -o yaml | kubectl apply -f -
```

The Secret key is deliberately named `id_ed25519`, matching the local values
file's documented expectation. Kubernetes Secrets are credentials: restrict
access to the cluster and never check the generated Secret YAML or private key
into Git.

Confirm that the Secret exists without printing its contents:

```bash
kubectl -n airflow get secret airflow-ssh-secret
```

## 3. Point Git sync at the private repository

Edit
[the local values file](../../platform/helm/airflow/values-local.yaml). Change
the repository to its SSH clone URL, and set `sshKeySecret` to the Secret name:

```yaml
dags:
  gitSync:
    enabled: true
    repo: git@github.com:OWNER/REPOSITORY.git
    branch: main
    subPath: "domains"
    wait: 120
    maxFailures: 0
    sshKeySecret: "airflow-ssh-secret"
```

Replace `OWNER/REPOSITORY` and adjust `branch` or `subPath` if needed. With the
current `subPath: "domains"`, the repository must contain the DAG files under
its `domains` directory. Keep the SSH URL (`git@github.com:...`), not the
HTTPS URL, when using this SSH key.

## 4. Apply the Helm values through Terraform

From the repository root, run:

```bash
terraform -chdir=infra/local apply
```

Terraform manages the Helm release and reads the local values file; applying
with Terraform ensures the setting is not overwritten by a later Terraform
run. Use the same kubeconfig/context and `postgres_password` inputs as for the
existing local stack. Terraform may prompt for the database password if it is
not supplied. As described in the
[local stack README](./README.md), keep Terraform state private.

## 5. Verify Git sync

Check the Airflow pods and find the pod(s) that include the `git-sync`
container:

```bash
kubectl -n airflow get pods
kubectl -n airflow get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{" "}{end}{"\n"}{end}'
```

Read the Git sync logs from a pod that lists the `git-sync` container, replacing
`POD_NAME` with the pod name from the output:

```bash
kubectl -n airflow logs POD_NAME -c git-sync --tail=100
```

Successful syncs should appear in the Git sync logs. Then open the Airflow UI
and confirm the expected DAGs are listed. The local stack README explains how
to access the UI.

## Troubleshooting and key rotation

- **Authentication or permission errors:** Verify the public key was added as
  a deploy key on the correct private repository, write access is not needed,
  and the SSH URL's owner and repository are correct.
- **Secret errors:** Confirm the Secret is in the `airflow` namespace and
  contains the `id_ed25519` key. Do not print or paste the Secret data when
  troubleshooting.
- **No DAGs appear:** Confirm the selected branch contains DAG files under the
  configured `subPath` (`domains` by default), then check the `git-sync` logs.
- **Rotate the key:** Generate and register a replacement deploy key, update
  the existing Secret with the same command in step 2, and restart the Airflow
  pods if Git sync does not pick up the changed Secret automatically. Remove
  the old deploy key from the repository once the new key has been verified.
