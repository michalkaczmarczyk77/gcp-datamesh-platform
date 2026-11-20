#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 || ( "$1" != "dlh-sales" && "$1" != "dlh-logistics" ) ]]; then
  echo "Usage: $0 dlh-sales|dlh-logistics" >&2
  exit 2
fi

KUBE_NAMESPACE="$1"
WORKING_DIRECTORY="/workspace/infra/local-gitsync-shared-pvc"

# Create the local directories on the Kubernetes node before applying these PVs.
#mkdir /mnt/git/${KUBE_NAMESPACE}
#sudo chown -R 65533:65533 /mnt/git/${KUBE_NAMESPACE}
#sudo chmod -R u+rwX,g+rwX /mnt/git/${KUBE_NAMESPACE}

kubectl apply -f "${WORKING_DIRECTORY}/${KUBE_NAMESPACE}-pv.yaml"

kubectl apply -f "${WORKING_DIRECTORY}/${KUBE_NAMESPACE}/namespace.yaml"
kubectl get namespace "${KUBE_NAMESPACE}"

kubectl apply -f "${WORKING_DIRECTORY}/${KUBE_NAMESPACE}/secret.yaml"
kubectl get secret -n "${KUBE_NAMESPACE}"

kubectl apply -f "${WORKING_DIRECTORY}/${KUBE_NAMESPACE}/storage.yaml"
kubectl get pvc -n "${KUBE_NAMESPACE}"

kubectl apply -f "${WORKING_DIRECTORY}/${KUBE_NAMESPACE}/deployment-pod1.yaml"
kubectl -n "${KUBE_NAMESPACE}" rollout status "deployment/${KUBE_NAMESPACE}-pod1"

kubectl -n "${KUBE_NAMESPACE}" exec "deploy/${KUBE_NAMESPACE}-pod1" -c git-sync -- id
kubectl -n "${KUBE_NAMESPACE}" exec "deploy/${KUBE_NAMESPACE}-pod1" -c git-sync -- ls -ldn /git /git/current /git/current/.git

PV=$(kubectl -n "${KUBE_NAMESPACE}" get pvc "${KUBE_NAMESPACE}-repo" -o jsonpath='{.spec.volumeName}')
kubectl get pv "${PV}" -o yaml
