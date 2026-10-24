# 1. Use a shared, versioned project volume

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
kubectl apply -f pvc.yaml
kubectl get pvc -n airflow
```

## Save DBT releases

Have CI or a Kubernetes publishing Job write complete releases to immutable directories, for example

```
/releases/<git-sha>/domains/finance/dbt/
/releases/<git-sha>/domains/sales/dbt/
```

Publish the dbt project, its dependencies, and the corresponding target/manifest.json together. Don’t overwrite files in a release currently used by DAGs or running tasks. Instead, publish a new SHA and deploy DAG configuration that references it.

# 2. Mount the PVC into Airflow’s DAG processor

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

```
/opt/dbt-releases/releases/<git-sha>/domains/finance/dbt/target/manifest.json
```

# 3. Mount the same PVC into each Cosmos dbt Pod
