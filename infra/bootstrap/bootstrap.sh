export BILLING="014F34-F31ECD-3A639F"
export TF_STATE_BUCKET="dtp-ref-tfstate"
export PROJECT_DEV="dtp-ref-dev"
export PROJECT_PRD="dtp-ref-prd"
export PROJECT_ID=$PROJECT_DEV
export REGION="europe-central2"

#export PROJECT (prd)    : dtp-ref-prd
#export GITHUB REPO      : <org>/data-transformation-platform

gcloud auth login
export PROJECT=caymanek-sandbox
gcloud config set project $PROJECT

#test connection
gcloud storage ls

# Create projects
gcloud projects create $PROJECT_DEV --name="DTP Reference Dev"
gcloud projects create $PROJECT_PRD --name="DTP Reference Prod"

for P in $PROJECT_DEV $PROJECT_PRD; do
  gcloud beta billing projects link $P --billing-account=$BILLING
  gcloud services enable \
    container.googleapis.com sqladmin.googleapis.com bigquery.googleapis.com pubsub.googleapis.com \
    artifactregistry.googleapis.com iam.googleapis.com \
    cloudresourcemanager.googleapis.com storage.googleapis.com \
    iamcredentials.googleapis.com sts.googleapis.com \
    datacatalog.googleapis.com --project=$P
done

# Check projects linked to the Billing Account
gcloud beta billing projects list --billing-account=$BILLING
gcloud beta billing projects describe $PROJECT_ID

# Terraform state bucket
gcloud config set project $PROJECT_DEV

gcloud storage buckets create gs://$TF_STATE_BUCKET \
  --project=$PROJECT_DEV --location=$REGION \
  --uniform-bucket-level-access
gcloud storage buckets update gs://$TF_STATE_BUCKET --versioning

# Check new gcs bucket
gcloud storage ls

### TERRAFORM BOOTSTRAP ###
unset GOOGLE_APPLICATION_CREDENTIALS
gcloud auth application-default login

terraform init
terraform apply

# sa_dbt_ci_email = "sa-dbt-ci@dtp-ref-dev.iam.gserviceaccount.com"
# sa_deploy_email = "sa-deploy@dtp-ref-dev.iam.gserviceaccount.com"
# sa_tf_apply_email = "sa-tf-apply@dtp-ref-dev.iam.gserviceaccount.com"
# sa_tf_plan_email = "sa-tf-plan@dtp-ref-dev.iam.gserviceaccount.com"
# wif_provider = "projects/dtp-ref-dev/locations/global/workloadIdentityPools/github-pool/providers/github-provider"


# Next steps
cd /workspaces/WeekendProject/infra/envs/dev
terraform init
terraform apply


# terraform destroy -target=google_sql_database.airflow
# terraform state rm google_sql_database.airflow

# Docker Image Google Artifact Repository
gcloud auth configure-docker europe-central2-docker.pkg.dev

docker pull us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
docker image ls
# us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0

# Before you push the Docker image to Artifact Registry, you must tag it with the repository name.
docker tag us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0 \
europe-central2-docker.pkg.dev/dtp-ref-dev/dtp-artifact-registry/quickstart-image:last

# Push image to the registry
docker push europe-central2-docker.pkg.dev/dtp-ref-dev/dtp-artifact-registry/quickstart-image:last

#gcloud artifacts repositories delete dtp-artifact-registry --location=europe-central2
