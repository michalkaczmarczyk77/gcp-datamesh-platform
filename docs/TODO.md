# TODO

- Spisać założenia projektowe
- Opisać sposób pracy z LLM, wynikłe problemy i jak zostały rozwiązane
- Opisać zestaw narzędzi użytych, zakres wiedzy, który został usystematyzowany i wzmocniony podczas projektu

- Draw.io diagram z faktycznie użytymi komponentami
- Odtworzenie platformy
- Stworzenie pełnego devcontainer z cały zakresem użytych narzędzi:
  - gcloud
  - dbt
  - docker
  - git
  - kubectl
  - terraform
  - helm
  - microk8s
  - m9s
  - OpenCode - z podłączeniem do Copilota


# Step by step instruction

### Set variables

```bash
export GCP_ENVIRONMENT=dev
export PROJECT_ID=dtp-ref-${GCP_ENVIRONMENT}
export REGION=europe-central2
export GKE_CLUSTER_NAME=dtp-cluster-${GCP_ENVIRONMENT}
export GCP_DOCKER_REPO=${REGION}-docker.pkg.dev
export TAG="3.3.2-python3.14"
export GCP_ARTIFACT_REGISTRY=dtp-artifact-registry
export IMAGE=${GCP_DOCKER_REPO}/${PROJECT_ID}/${GCP_ARTIFACT_REGISTRY}/airflow-dbt:${TAG}
```
### 1. Bootstrap (jednorazowo)

Utworzenie podstawowych komponentów infrastruktury GCP:

- GCP Projects
- Storage Buckets: dla plików stanu terraform
- WIF: pools, providers, bindings
- Service Accounts & Roles
- Artifact Registry

```bash
cd infra/bootstrap
./bootstrap.sh
```

### Zbudowanie obrasu Airflow

Zbudowanie inicjalnego obrazu dokerowego dla Airflow i umieszczenie w repozytorium

```bash
gcloud auth configure-docker $GCP_DOCKER_REPO --quiet
docker build -t $IMAGE -f platform/docker/airflow/Dockerfile platform/docker/airflow
docker images
docker push $IMAGE
```

# Next steps
cd infra/envs/dev
terraform init
terraform apply

