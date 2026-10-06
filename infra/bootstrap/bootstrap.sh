export BILLING="014F34-F31ECD-3A639F"
export TF_STATE_BUCKET="dtp-ref-tfstate"
export PROJECT_DEV="dtp-ref-dev"
export PROJECT_PRD="dtp-ref-prd"
export PROJECT_ID=$PROJECT_DEV
export REGION="europe-central2"

gcloud auth login
gcloud config set project caymanek-sandbox

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

terraform init
terraform apply

# sa_dbt_ci_email = "sa-dbt-ci@dtp-ref-dev.iam.gserviceaccount.com"
# sa_deploy_email = "sa-deploy@dtp-ref-dev.iam.gserviceaccount.com"
# sa_tf_apply_email = "sa-tf-apply@dtp-ref-dev.iam.gserviceaccount.com"
# sa_tf_plan_email = "sa-tf-plan@dtp-ref-dev.iam.gserviceaccount.com"
# wif_provider = "projects/dtp-ref-dev/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
