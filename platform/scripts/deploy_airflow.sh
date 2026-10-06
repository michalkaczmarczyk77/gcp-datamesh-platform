#!/usr/bin/env bash
set -euo pipefail

# Mirrors the "Helm upgrade" step in .github/workflows/cd-deploy.yml, for
# local/manual use (Phase 7, Step 3.4 area). The image itself must already
# be built and pushed — this script only points Helm at the cluster
# Terraform created and rolls out an existing image tag.
#
# Usage: ENV=dev IMAGE_TAG=<sha-or-tag> ./platform/scripts/deploy_airflow.sh

ENV="${ENV:-dev}"
IMAGE_TAG="${IMAGE_TAG:?Set IMAGE_TAG to the image tag to deploy, e.g. IMAGE_TAG=$(git rev-parse HEAD)}"
PROJECT="dtp-ref-${ENV}"
REGION="europe-central2"
REPO="europe-central2-docker.pkg.dev/${PROJECT}/dtp/airflow-dbt"

echo "==> Fetching GKE credentials for airflow-${ENV} (${PROJECT})"
gcloud container clusters get-credentials "airflow-${ENV}" \
  --region "${REGION}" --project "${PROJECT}"

echo "==> helm upgrade airflow -> ${REPO}:${IMAGE_TAG}"
helm repo add apache-airflow https://airflow.apache.org >/dev/null
helm repo update >/dev/null
helm upgrade airflow apache-airflow/airflow \
  --namespace airflow --reuse-values \
  --set images.airflow.repository="${REPO}" \
  --set images.airflow.tag="${IMAGE_TAG}" \
  --wait --timeout 10m

echo "==> Rollout status"
kubectl -n airflow rollout status deployment/airflow-scheduler --timeout=300s
