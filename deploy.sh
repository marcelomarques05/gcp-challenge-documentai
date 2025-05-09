# Challenge Lab

git clone https://github.com/marcelomarques05/gcp-challenge-documentai.git
cd gcp-challenge-documentai

# Enable GCP services
gcloud services enable \
  aiplatform.googleapis.com \
  artifactregistry.googleapis.com \
  bigquery.googleapis.com \
  cloudbuild.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudresourcemanager.googleapis.com \
  compute.googleapis.com \
  config.googleapis.com \
  documentai.googleapis.com \
  eventarc.googleapis.com \
  iam.googleapis.com \
  run.googleapis.com \
  serviceusage.googleapis.com \
  storage-api.googleapis.com \
  storage.googleapis.com

# Environment (UPDATE HERE ONLY)
export PROJECT_ID="{Your Project ID}"
export REGION="us-central1"
export LOCATION="us"
export MAIN_BUCKET="challenge-main-bucket"
export DOCS_BUCKET="challenge-docs-bucket"
export WEBHOOK_NAME="challenge-webhook"
export WEBHOOK_SA_NAME="challenge-webhook-sa"
export TRIGGER_NAME="challenge-trigger"
export TRIGGER_SA_NAME="challenge-trigger-sa"
export ARTIFACT_REPO_NAME="challenge-repo"
export DATASET_NAME="challenge_dataset"
export TABLE_NAME="summaries"
export PROJECT_NUMBER=`gcloud projects describe $PROJECT_ID --format='value(projectNumber)'`
export OCR_PROCESSOR_NAME="challenge-ocr-processor"
export GCS_SA=`gcloud storage service-agent --project=$PROJECT_ID`

# Create Buckets
gsutil mb gs://$MAIN_BUCKET gs://$DOCS_BUCKET

# Create Repo in Artifact Registry
gcloud artifacts repositories create $ARTIFACT_REPO_NAME \
  --project=$PROJECT_ID \
  --repository-format=docker \
  --location=$REGION

# Create Service Accounts
gcloud iam service-accounts create $WEBHOOK_SA_NAME \
  --project=$PROJECT_ID \
  --display-name="summary webhook service account"

gcloud iam service-accounts create $TRIGGER_SA_NAME \
  --project=$PROJECT_ID \
  --display-name="summary trigger service account"

# Grant Roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.serviceAgent"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/documentai.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$TRIGGER_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/eventarc.eventReceiver"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$TRIGGER_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GCS_SA" \
  --role="roles/pubsub.publisher"

gcloud beta services identity create \
  --service=eventarc.googleapis.com \
  --project=$PROJECT_ID

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com" \
  --role="roles/eventarc.serviceAgent"

# Document AI
curl -X POST \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json; charset=utf-8" \
     -d "{
            \"type\": \"OCR_PROCESSOR\",
            \"displayName\": \"${OCR_PROCESSOR_NAME}\"
        }" \
     "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors"

export OCR_PROCESSOR_ID=`curl -X GET -s \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors" \
  | jq -r '.processors[0].name' | awk -F/ '{print $6}'`

# BigQuery Dataset and Table
gcloud alpha bq datasets create $DATASET_NAME \
  --project=$PROJECT_ID

gcloud alpha bq tables create $TABLE_NAME --dataset $DATASET_NAME \
  --project=$PROJECT_ID \
  --schema="event_id=STRING,time_uploaded=TIMESTAMP,time_processed=TIMESTAMP,document_path=STRING,document_text=STRING,document_summary=STRING"

# Copy Code to Bucket
git clone https://github.com/GoogleCloudPlatform/terraform-genai-doc-summarization.git
cd terraform-genai-doc-summarization/webhook/
zip -r webhook_staging.zip . -x "./.git/*"
gsutil cp webhook_staging.zip gs://$MAIN_BUCKET/webhook_staging.zip

# Cloud Functions
gcloud functions deploy $WEBHOOK_NAME \
  --gen2 \
  --region=$REGION \
  --runtime=python312 \
  --entry-point="on_cloud_event" \
  --source="gs://${MAIN_BUCKET}/webhook_staging.zip" \
  --memory=1Gi \
  --service-account=$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
  --trigger-service-account=$TRIGGER_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
  --docker-repository="projects/${PROJECT_ID}/locations/${REGION}/repositories/${ARTIFACT_REPO_NAME}" \
  --set-env-vars=\
PROJECT_ID=$PROJECT_ID,\
LOCATION=$REGION,\
OUTPUT_BUCKET="$MAIN_BUCKET",\
DOCAI_PROCESSOR="projects/${PROJECT_NUMBER}/locations/${LOCATION}/processors/$OCR_PROCESSOR_ID",\
DOCAI_LOCATION=$LOCATION,\
BQ_DATASET=$DATASET_NAME,\
BQ_TABLE=$TABLE_NAME,\
LOG_EXECUTION_ID=true  \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=${MAIN_BUCKET}" \
  --trigger-location=$LOCATION

# Test Trigger
gcloud storage cp gs://arxiv-dataset/arxiv/cmp-lg/pdf/9410/9410009v1.pdf gs://${MAIN_BUCKET}/
