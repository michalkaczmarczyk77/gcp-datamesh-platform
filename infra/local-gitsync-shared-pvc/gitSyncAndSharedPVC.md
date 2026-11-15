# Solution: gitSync and Shared PVC

The repository PVCs use static `hostPath` PVs. The paths in the PV manifest are
paths on the Kubernetes node, so this setup writes into the laptop's
`/mnt/git` only when the node runs directly on that laptop (not inside a VM or
container with a separate filesystem).

```bash
# Run on the Kubernetes node. git-sync runs as UID/GID 65533 in this setup.
sudo install -d -o 65533 -g 65533 -m 0770 \
  /mnt/git/dlh-sales \
  /mnt/git/dlh-logistics \
  /mnt/git/shared-repos/dlh-sales \
  /mnt/git/shared-repos/pod2

# Apply the static PVs before creating the PVCs.
kubectl apply -f /workspace/infra/local-gitsync-shared-pvc/persistent-volume.yaml

kubectl get pv

# Deploy either application. The script applies the static PVs, namespace,
# Secret, PVC, and Deployment; its namespace argument is dlh-sales or
# dlh-logistics.
/workspace/infra/local-gitsync-shared-pvc/kube-deploy.sh dlh-sales
/workspace/infra/local-gitsync-shared-pvc/kube-deploy.sh dlh-logistics

# Verify claims and actual node paths:
kubectl get pv -o custom-columns='NAME:.metadata.name,CLAIM:.spec.claimRef.namespace/.spec.claimRef.name,PATH:.spec.hostPath.path,STATUS:.status.phase'
kubectl -n dlh-sales exec deploy/dlh-sales-pod1 -c git-sync -- ls -la /git
```

To start a read-only Pod that can inspect every repository under the node's
`/mnt/git`, apply the reader manifests after deploying sales or logistics:

```bash
kubectl apply -f /workspace/infra/local-gitsync-shared-pvc/repo-reader/namespace.yaml
kubectl apply -f /workspace/infra/local-gitsync-shared-pvc/repo-reader/deployment.yaml
kubectl -n repo-reader rollout status deployment/git-repo-reader
kubectl -n repo-reader exec deployment/git-repo-reader -- ls -la /repositories
```

The reader mounts `/mnt/git` directly at `/repositories` and uses required Pod
affinity to land on the same node as a sales or logistics Pod. It sees, for
example, `/repositories/dlh-sales/current` and
`/repositories/dlh-logistics/current`. The mount is read-only so the reader
cannot modify or interfere with git-sync's checkouts.

For an existing installation, back up any data you need before replacing PVCs.
PVC storage class and volume binding are not generally mutable after binding;
the new PVC definitions may require recreating the claims. The `Retain`
reclaim policy preserves the PV data when a claim is released, but verify the
old PV and its data before deleting any PVC.

For sales and logistics, the checkout is under `/mnt/git/dlh-sales/current` and
`/mnt/git/dlh-logistics/current`, respectively. The shared example keeps its
checkouts under `/mnt/git/shared-repos/dlh-sales/current` and
`/mnt/git/shared-repos/pod2/current`.

The YAML example below is a separate NFS illustration; it is not used by these
hostPath manifests and does not configure the laptop's `/mnt/git`.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-shared-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: nfs-server.storage.svc.cluster.local # Adres IP lub nazwa DNS serwera NFS
    path: /srv/nfs/shared-git-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-shared-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: 10Gi
  volumeName: nfs-shared-pv
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-git-syncer
  namespace: default
  labels:
    app: nfs-git-syncer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-git-syncer
  template:
    metadata:
      labels:
        app: nfs-git-syncer
    spec:
      containers:
      - name: git-sync
        image: registry.k8s.io/git-sync/git-sync:v4.2.4
        args:
        - --repo=https://github.com/twoja-org/twoj-repozytorium.git
        - --branch=main
        - --root=/nfs-data
        - --period=30s
        # Opcjonalnie: obsługa webhooka (natychmiastowe odświeżenie po push):
        # - --webhook-port=8080
        securityContext:
          runAsUser: 65535 # Uruchomienie jako użytkownik nieuprzywilejowany
        volumeMounts:
        - name: shared-nfs
          mountPath: /nfs-data
      volumes:
      - name: shared-nfs
        persistentVolumeClaim:
          claimName: nfs-shared-pvc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-pod-a
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-a
  template:
    metadata:
      labels:
        app: app-a
    spec:
      containers:
      - name: app-a-container
        image: nginx:alpine
        volumeMounts:
        - name: shared-nfs
          mountPath: /usr/share/nginx/html
          subPath: catalog-a  # Montuje tylko podkatalog catalog-a z NFS
      volumes:
      - name: shared-nfs
        persistentVolumeClaim:
          claimName: nfs-shared-pvc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-pod-b
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-b
  template:
    metadata:
      labels:
        app: app-b
    spec:
      containers:
      - name: app-b-container
        image: nginx:alpine
        volumeMounts:
        - name: shared-nfs
          mountPath: /usr/share/nginx/html
          subPath: catalog-b  # Montuje tylko podkatalog catalog-b z NFS
      volumes:
      - name: shared-nfs
        persistentVolumeClaim:
          claimName: nfs-shared-pvc
```