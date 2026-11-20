# 1. Use a shared, versioned project volume

See Appendix 1: to check how to configure local NFS server and how to register NFS divers into microk8s on Ubuntu

## Create Persistent Volume Claim

Before You create PVC, storage class must be defined and deployed on Kubernetes

```yaml
# pvc/pvc-local.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbt-releases
  namespace: airflow
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-rwx
  resources:
    requests:
      storage: 10Gi
```

```bash
kubectl create namespace airflow
kubectl get storageclass
# edit pvc.yaml and set a real storageClassName
kubectl apply -f pvc/pvc-local.yaml
kubectl get pvc -n airflow

# microk8s enable hostpath-storage
```

## Save DBT releases

Have CI or a Kubernetes publishing Job write complete releases to immutable directories, for example

```
/releases/<git-sha>/domains/finance/dbt/
/releases/<git-sha>/domains/sales/dbt/
```

Publish the dbt project, its dependencies, and the corresponding target/manifest.json together. Don’t overwrite files in a release currently used by DAGs or running tasks. Instead, publish a new SHA and deploy DAG configuration that references it.

# 2. Mount the PVC into Airflow’s *DAG processor*

Your DAGs can continue to arrive through Git sync. Mount the release PVC read-only into the component that parses them—on your Airflow 3 setup, that’s the DAG processor. For the chart component’s extraVolumes and extraVolumeMounts values, the shape is approximately:

```yaml
# /workspace/platform/helm/airflow/values-local.yaml
dagProcessor:
  extraVolumes:
    - name: dbt-releases
      persistentVolumeClaim:
        claimName: dbt-releases
  extraVolumeMounts:
    - name: dbt-releases
      mountPath: /opt/dbt-releases
      readOnly: true
```

Check the exact keys against the chart version you install. The DAG processor can then read a manifest such as:

    /opt/dbt-releases/releases/<git-sha>/domains/finance/dbt/target/manifest.json

# 3. Mount the same PVC into each *Cosmos dbt Pod* 
(?? why Cosmos dbt POD - cosmos miał być elementem śr. Airflow)

With Cosmos’s Kubernetes execution mode, operator_args can pass KubernetesPodOperator options such as volumes and mounts. Give each task Pod:

- A read-only mount of the release PVC.
- A writable emptyDir for its copy of the project and dbt output.
- An init container that copies the selected project release into that workspace. (???)

Conceptually, the mounts are:

    PVC, read-only:  /opt/dbt-releases
    emptyDir:        /opt/dbt-work

Then point Cosmos execution at /opt/dbt-work. This avoids concurrent dbt tasks writing target/ files into the shared release. The PVC needs to be mounted into each dbt task Pod, not just the Airflow scheduler or KubernetesExecutor worker.

# 4. Configure the Cosmos paths to match

In your [Cosmos factory](/platform/dags_common/cosmos_factory.py), use the PVC path for parsing and the Pod workspace path for execution. For example, the key settings would look like:

```py
from pathlib import Path

from cosmos import ExecutionConfig, ExecutionMode, LoadMode

release_project = (
    Path("/opt/dbt-releases")
    / "releases"
    / DBT_RELEASE_SHA
    / "domains"
    / domain
    / "dbt"
)

# In DbtTaskGroup:
project_config=ProjectConfig(
    dbt_project_path=release_project,
    manifest_path=release_project / "target" / "manifest.json",
),
render_config=RenderConfig(
    load_method=LoadMode.DBT_MANIFEST,
),
execution_config=ExecutionConfig(
    execution_mode=ExecutionMode.KUBERNETES,
    dbt_project_path="/opt/dbt-work",
),
```

The DAG processor reads the manifest from the immutable PVC release. Each dbt Pod copies that same release into /opt/dbt-work before executing. In operator_args, pass the dbt runtime image, PVC and emptyDir volume definitions, their mounts, and the init container. Cosmos’s Kubernetes execution guide documents the Kubernetes execution mode and passing KubernetesPodOperator options through operator_args.

# 5. Keep credentials out of the shared project

If profiles.yml is needed, it must be readable by both the Airflow parser and the dbt Pod. Keep credentials out of that file: have it refer to environment variables, then inject those variables into the dbt Pod from Kubernetes Secrets or your cluster’s workload-identity mechanism. Don’t place credentials in the PVC, Git repository, or image.

Also grant the identity used by the Airflow task that runs the KubernetesPodOperator permission to create, read, watch, and delete Pods and read their logs in the airflow namespace. The dbt Pod’s own service account should have only the access dbt needs.

This keeps the project in shared storage rather than the dbt image, while keeping each run tied to a particular project and manifest revision. Your current Git-synced path can remain for DAG code; the shared PVC provides the versioned dbt project release to the parser and task Pods.


# Appendix: NFS installation

On **MicroK8s on Ubuntu**, the standard way to get an **NFS-backed StorageClass** is:

1. run or install an **NFS server** on the Ubuntu host
2. install the **NFS client provisioner / CSI driver** in MicroK8s
3. create a **StorageClass** that provisions PVs from that NFS share
4. point your PVC to that StorageClass

MicroK8s has an official guide for using NFS for persistent volumes, and the general pattern is consistent with Kubernetes best practices: **NFS provides shared storage**, and the **StorageClass automates PV creation**.

## Recommended setup

### Option A: NFS server on the same Ubuntu machine
This is the simplest for a local lab. You export a directory from Ubuntu and let MicroK8s mount it.

### Option B: NFS server on another machine
Use this if you already have a NAS or another Linux box serving NFS.

For a local cluster, Option A is usually easiest.

---

## Step 1: Install and configure NFS server on Ubuntu

On the Ubuntu host:

```bash
sudo apt update
sudo apt install -y nfs-kernel-server
```

Create a shared directory:

```bash
sudo mkdir -p /srv/nfs/k8s
sudo chown nobody:nogroup /srv/nfs/k8s
sudo chmod 0777 /srv/nfs/k8s
```

Export it by editing `/etc/exports`:

```bash
sudo nano /etc/exports
```

Add this line:

```text
/srv/nfs/k8s *(rw,sync,no_subtree_check,no_root_squash)
```

Apply the export:

```bash
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
```

Check:

```bash
showmount -e localhost
```

---

## Step 2: Enable MicroK8s storage addon

If you have not already:

```bash
microk8s enable hostpath-storage
```

That is useful for default storage, but for RWX you still want NFS.

---

## Step 3: Install an NFS provisioner in MicroK8s

A common approach is to install **nfs-subdir-external-provisioner**. It dynamically creates a subdirectory per PVC inside your NFS export.

First, make sure MicroK8s can reach your NFS server.

If the NFS server is the same Ubuntu machine, use the host IP or `localhost` depending on networking. In many cases it is safer to use the machine IP on the LAN.

---

## Step 4: Create the namespace and RBAC/provisioner resources

A typical manifest looks like this:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nfs-provisioner
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: nfs-provisioner
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes", "persistentvolumes", "persistentvolumeclaims", "endpoints", "pods"]
    verbs: ["get", "list", "watch", "create", "delete", "patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: run-nfs-client-provisioner
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: nfs-client-provisioner-runner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: nfs-provisioner
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: nfs-provisioner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: example.com/nfs
            - name: NFS_SERVER
              value: YOUR_UBUNTU_IP
            - name: NFS_PATH
              value: /srv/nfs/k8s
      volumes:
        - name: nfs-client-root
          nfs:
            server: YOUR_UBUNTU_IP
            path: /srv/nfs/k8s
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-rwx
provisioner: example.com/nfs
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

Replace `YOUR_UBUNTU_IP` with the IP address of the Ubuntu machine.

Apply it:

```bash
kubectl apply -f nfs-provisioner.yaml
```

---

## Step 5: Use the StorageClass in your PVC

Now your PVC can use RWX:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbt-releases
  namespace: airflow
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-rwx
  resources:
    requests:
      storage: 10Gi
```

Apply:

```bash
kubectl create namespace airflow
kubectl apply -f pvc.yaml
```

Check status:

```bash
kubectl get pvc -n airflow
kubectl get pv
```

You should see it bound.

---

## Common issues

### 1) PVC stays Pending
Usually one of these:
- wrong `storageClassName`
- NFS server not reachable
- NFS export path wrong
- provisioner pod not running

Check:

```bash
kubectl get pods -n nfs-provisioner
kubectl describe pvc dbt-releases -n airflow
```

### 2) Permission problems
If the mounted directory has permission issues, make sure the export and directory permissions are relaxed enough for testing.

### 3) Firewall blocks NFS
Make sure Ubuntu firewall allows NFS traffic if needed.

---

## Simplest practical answer

If you want the shortest path on MicroK8s:

- install `nfs-kernel-server` on Ubuntu
- export `/srv/nfs/k8s`
- install `nfs-subdir-external-provisioner`
- create StorageClass `nfs-rwx`
- set your PVC to `storageClassName: nfs-rwx`

---

If you want, I can give you a **single copy-paste YAML file** for MicroK8s with:
- Namespace
- RBAC
- NFS provisioner Deployment
- StorageClass
- and your PVC

so you can apply everything in one shot.


# Appendix 2: nfs-subdir-external-provisioner

A common approach is to install nfs-subdir-external-provisioner. It dynamically creates a subdirectory per PVC inside your NFS export.

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<YOUR-NFS-SERVER-IP-OR-HOSTNAME> \
  --set nfs.path=<YOUR-NFS-EXPORT-PATH>
```
