export BILLING="014F34-F31ECD-3A639F"
export SOLUTION="dtp-ref"
export GCP_ENVIRONMENT="dev"
export REGION="europe-central2"
export PROJECT_INIT="caymanek-sandbox"
export GCP_ARTIFACT_REGISTRY="dtp-artifact-registry"
export TAG="3.3.2-python3.14"

export GCP_DOCKER_REPO=${REGION}-docker.pkg.dev
export TF_STATE_BUCKET="${SOLUTION}-tfstate"
export PROJECT_DEV="${SOLUTION}-dev"
export PROJECT_PRD="${SOLUTION}-prd"
export PROJECT_ID=${SOLUTION}-${GCP_ENVIRONMENT}
export IMAGE=${GCP_DOCKER_REPO}/${PROJECT_ID}/${GCP_ARTIFACT_REGISTRY}/airflow-dbt:${TAG}

gcloud auth login
gcloud config set project ${PROJECT_INIT}

# Create projects
gcloud projects create $PROJECT_DEV --name="DTP Reference Dev"
gcloud projects create $PROJECT_PRD --name="DTP Reference Prod"

for P in $PROJECT_DEV $PROJECT_PRD; do
  gcloud beta billing projects link $P --billing-account=$BILLING
  gcloud services enable \
    container.googleapis.com \
    sqladmin.googleapis.com \
    bigquery.googleapis.com \
    pubsub.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    storage.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com \
    datacatalog.googleapis.com \
    --project=$P
done

# Check projects linked to the Billing Account
gcloud beta billing projects list --billing-account=$BILLING
gcloud beta billing projects describe $PROJECT_DEV
gcloud beta billing projects describe $PROJECT_PRD

# Terraform state bucket
gcloud config set project $PROJECT_DEV

gcloud storage buckets create gs://$TF_STATE_BUCKET \
  --project=$PROJECT_DEV --location=$REGION \
  --uniform-bucket-level-access
gcloud storage buckets update gs://$TF_STATE_BUCKET --versioning

# Check new gcs bucket
gcloud storage ls

### TERRAFORM BOOTSTRAP ###
gcloud auth application-default login

### Zbudowanie obrasu Airflow

# Inicjalna budowa obrazu dokerowego dla Airflow i umieszczenie w repozytorium

gcloud auth configure-docker $GCP_DOCKER_REPO --quiet
docker build -t $IMAGE -f ../../platform/docker/airflow/Dockerfile ../../platform/docker/airflow
docker images
docker push $IMAGE


#cd ./core
#terraform init
#terraform plan  -var-file="../${PROJECT_DEV}.tfvars"
#terraform apply -var-file="../${PROJECT_DEV}.tfvars"
#cd ..

terraform init
terraform plan  -var-file="${PROJECT_DEV}.tfvars"
terraform apply -var-file="${PROJECT_DEV}.tfvars"

