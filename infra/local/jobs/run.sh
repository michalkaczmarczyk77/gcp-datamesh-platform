#!/bin/bash

export KUBE_NAMESPACE="airflow"

kubectl create namespace ${KUBE_NAMESPACE}
kubectl apply -f /workspace/infra/local/pvc/pvc-local.yaml
kubectl apply -f /workspace/infra/local/jobs/clone-public-repository.yaml

kubectl get namespace ${KUBE_NAMESPACE}
kubectl -n ${KUBE_NAMESPACE} get pvc
kubectl -n ${KUBE_NAMESPACE} get 
