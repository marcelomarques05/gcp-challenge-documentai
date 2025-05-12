#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Google Cloud resource bootstrap script.

Options:
  --project <ID>       GCP Project ID
  --region <REGION>    GCP region (default: us-central1)
  --location <LOC>     Resources location (default: us)
  --suffix <SUFFIX>    4-char resource suffix (optional)
  -h, --help           Show this help and exit

You can also set PROJECT_ID, REGION, LOCATION, SUFFIX_ID as environment variables.
If not provided, the script will prompt for missing values and suggest defaults.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_ID="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --location)
      LOCATION="$2"
      shift 2
      ;;
    --suffix)
      SUFFIX_ID="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
done

validate_env() {
  local missing=()
  local invalid=()

  # PROJECT_ID
  if [ -z "${PROJECT_ID:-}" ]; then
    read -rp "Enter your GCP Project ID: " PROJECT_ID
  fi
  if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo "❌ PROJECT_ID '$PROJECT_ID' does not exist or you lack access."
    exit 1
  fi

  ## REGION
if [ -z "${REGION:-}" ]; then
  read -rp "Enter your region (us-central1): " REGION
  REGION="${REGION:-us-central1}"
fi
# Optionally: Warn user, but don't fail
echo "➡️  Using region: $REGION (ensure this is valid for your resource type and project)"

  # LOCATION
  if [ -z "${LOCATION:-}" ]; then
    read -rp "Enter your resources location (us): " LOCATION
    LOCATION="${LOCATION:-us}"
  fi
  if [[ ! "$LOCATION" =~ ^(us|eu)$ ]]; then
    echo "❌ LOCATION '$LOCATION' is not valid; must be 'us' or 'eu'."
    exit 1
  fi

  export PROJECT_ID REGION LOCATION
  echo "✅ All environment variables are valid."
}

# Suffix logic
SUFFIX_FILE="${SCRIPT_DIR}/.suffix_id"
if [ -z "${SUFFIX_ID:-}" ]; then
  if [ -f "$SUFFIX_FILE" ]; then
    SUFFIX_ID=$(cat "$SUFFIX_FILE")
  else
    SUFFIX_ID=$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)
    echo "$SUFFIX_ID" > "$SUFFIX_FILE"
  fi
else
  echo "$SUFFIX_ID" > "$SUFFIX_FILE"
fi
export SUFFIX_ID

validate_env

export MAIN_BUCKET="challenge-main-bucket-${SUFFIX_ID}"
export DOCS_BUCKET="challenge-docs-bucket-${SUFFIX_ID}"
export WEBHOOK_NAME="challenge-webhook-${SUFFIX_ID}"
export WEBHOOK_SA_NAME="challenge-webhook-sa-${SUFFIX_ID}"
export TRIGGER_NAME="challenge-trigger-${SUFFIX_ID}"
export TRIGGER_SA_NAME="challenge-trigger-sa-${SUFFIX_ID}"
export ARTIFACT_REPO_NAME="challenge-repo-${SUFFIX_ID}"
export DATASET_NAME="challenge_dataset_${SUFFIX_ID}"
export TABLE_NAME="summaries"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export OCR_PROCESSOR_NAME="challenge-ocr-processor-${SUFFIX_ID}"
export GCS_SA=$(gcloud storage service-agent --project=$PROJECT_ID)

#---------------------------#
echo "🚀 Enabling GCP services..."
#---------------------------#
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
  storage.googleapis.com \
  --project=$PROJECT_ID --quiet

echo "✅ GCP services enabled."

#---------------------------#
echo "🚀 Creating buckets..."
#---------------------------#
for BUCKET in "$MAIN_BUCKET" "$DOCS_BUCKET"; do
  if gsutil ls -b "gs://$BUCKET" >/dev/null 2>&1; then
    echo "   - Bucket $BUCKET already exists, skipping."
  else
    gsutil mb -p "$PROJECT_ID" -c STANDARD -l "$REGION" -b on "gs://$BUCKET"
    echo "   - Bucket $BUCKET created."
  fi
done
echo "✅ Buckets created."

#---------------------------#
echo "🚀 Creating Artifact Registry repository..."
#---------------------------#
if gcloud artifacts repositories describe "$ARTIFACT_REPO_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "   - Artifact Registry repo $ARTIFACT_REPO_NAME already exists, skipping."
else
  gcloud artifacts repositories create "$ARTIFACT_REPO_NAME" \
    --repository-format=docker \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
  echo "   - Artifact Registry repo $ARTIFACT_REPO_NAME created."
fi
echo "✅ Artifact Registry repository ready."

#---------------------------#
echo "🚀 Creating service accounts..."
#---------------------------#
for SA in "$WEBHOOK_SA_NAME" "$TRIGGER_SA_NAME"; do
  if gcloud iam service-accounts describe "$SA@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "   - Service account $SA already exists, skipping."
  else
    gcloud iam service-accounts create "$SA" \
      --project="$PROJECT_ID" \
      --display-name="$SA" \
      --quiet
    echo "   - Service account $SA created."
  fi
done
echo "✅ Service accounts ready."

#---------------------------#
echo "🚀 Assigning IAM roles..."
#---------------------------#
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.serviceAgent" --quiet >/dev/null 2>&1

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor" --quiet >/dev/null 2>&1

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/documentai.admin" --quiet >/dev/null 2>&1

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$TRIGGER_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/eventarc.eventReceiver" --quiet >/dev/null 2>&1

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$TRIGGER_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker" --quiet >/dev/null 2>&1

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$GCS_SA" \
  --role="roles/pubsub.publisher" --quiet >/dev/null 2>&1

gcloud beta services identity create \
  --service=eventarc.googleapis.com \
  --project="$PROJECT_ID" --quiet || true

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com" \
  --role="roles/eventarc.serviceAgent" --quiet >/dev/null 2>&1

echo "✅ IAM roles assigned."

#---------------------------#
echo "🚀 Creating Document AI processor..."
#---------------------------#
EXISTING_PROCESSOR_ID=$(curl -s \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors" \
  | jq -r --arg name "$OCR_PROCESSOR_NAME" '.processors[] | select(.displayName==$name) | .name' | awk -F/ '{print $6}' | head -n1 || true)

if [[ -n "$EXISTING_PROCESSOR_ID" ]]; then
  OCR_PROCESSOR_ID="$EXISTING_PROCESSOR_ID"
  echo "   - Document AI processor $OCR_PROCESSOR_NAME already exists, skipping creation."
else
  OCR_PROCESSOR_ID=$(curl -s -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "{\"type\": \"OCR_PROCESSOR\", \"displayName\": \"${OCR_PROCESSOR_NAME}\"}" \
    "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors" \
    | jq -r '.name' | awk -F/ '{print $6}')
  echo "   - Document AI processor $OCR_PROCESSOR_NAME created."
fi
if [[ -z "$OCR_PROCESSOR_ID" || "$OCR_PROCESSOR_ID" == "null" ]]; then
  echo "❌ Failed to create Document AI processor."
  exit 1
fi
export OCR_PROCESSOR_ID
echo "✅ Document AI processor ready."

#---------------------------#
echo "🚀 Creating BigQuery dataset and table..."
#---------------------------#
if bq show "$PROJECT_ID:$DATASET_NAME"; then
  echo "   - Dataset $DATASET_NAME already exists, skipping."
else
  bq mk --dataset "$PROJECT_ID:$DATASET_NAME"
  echo "   - Dataset $DATASET_NAME created."
fi

if bq show "$PROJECT_ID:$DATASET_NAME.$TABLE_NAME" >/dev/null 2>&1; then
  echo "   - Table $TABLE_NAME already exists, skipping."
else
  bq --project_id="$PROJECT_ID" query --use_legacy_sql=false --quiet \
    "CREATE TABLE IF NOT EXISTS \`$PROJECT_ID.$DATASET_NAME.$TABLE_NAME\` (
      event_id STRING,
      time_uploaded TIMESTAMP,
      time_processed TIMESTAMP,
      document_path STRING,
      document_text STRING,
      document_summary STRING
    )"
  echo "   - Table $TABLE_NAME created."
fi

#---------------------------#
echo "🚀 Uploading Cloud Function code..."
#---------------------------#
if [ ! -d ${SCRIPT_DIR}/../backend ]; then
  echo "❌ Directory ../backend does not exist!"
  exit 1
fi
zip -jqr ${SCRIPT_DIR}/webhook_staging.zip ${SCRIPT_DIR}/../backend/main.py ${SCRIPT_DIR}/../backend/requirements.txt
gsutil cp ${SCRIPT_DIR}/webhook_staging.zip "gs://$MAIN_BUCKET/webhook_staging.zip"
rm -f ${SCRIPT_DIR}/webhook_staging.zip
echo "✅ Cloud Function code uploaded."

#---------------------------#
echo "🚀 Deploying Cloud Function..."
#---------------------------#
if gcloud functions describe "$WEBHOOK_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "   - Cloud Function $WEBHOOK_NAME already exists, skipping deployment."
else
  gcloud functions deploy "$WEBHOOK_NAME" \
    --gen2 \
    --region="$REGION" \
    --runtime=python312 \
    --entry-point="on_cloud_event" \
    --source="gs://${MAIN_BUCKET}/webhook_staging.zip" \
    --memory=1Gi \
    --service-account="$WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --trigger-service-account="$TRIGGER_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --docker-repository="projects/${PROJECT_ID}/locations/${REGION}/repositories/${ARTIFACT_REPO_NAME}" \
    --set-env-vars=PROJECT_ID=$PROJECT_ID,LOCATION=$REGION,OUTPUT_BUCKET="$DOCS_BUCKET",DOCAI_PROCESSOR="projects/${PROJECT_NUMBER}/locations/${LOCATION}/processors/$OCR_PROCESSOR_ID",DOCAI_LOCATION=$LOCATION,BQ_DATASET=$DATASET_NAME,BQ_TABLE=$TABLE_NAME,LOG_EXECUTION_ID=true \
    --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
    --trigger-event-filters="bucket=${MAIN_BUCKET}" \
    --trigger-location="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
  echo "   - Cloud Function $WEBHOOK_NAME deployed."
fi
echo "✅ Cloud Function ready."

#---------------------------#

RESOURCE_SUMMARY_FILE="${SCRIPT_DIR}/resources-${SUFFIX_ID}.txt"
echo "📦 Writing resource summary to $RESOURCE_SUMMARY_FILE..."

cat <<EOF > "$RESOURCE_SUMMARY_FILE"
GCP Resource Summary (Suffix: ${SUFFIX_ID})

Project ID:          $PROJECT_ID
Project Number:      $PROJECT_NUMBER
Region:              $REGION
Location:            $LOCATION

Storage Buckets:
  - $MAIN_BUCKET
  - $DOCS_BUCKET

Artifact Registry:
  - $ARTIFACT_REPO_NAME

Service Accounts:
  - $WEBHOOK_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
  - $TRIGGER_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
  - GCS Service Agent: $GCS_SA

Document AI Processor:
  - $OCR_PROCESSOR_NAME (ID: $OCR_PROCESSOR_ID)

BigQuery:
  - Dataset: $DATASET_NAME
  - Table:   $TABLE_NAME

Cloud Function:
  - Name: $WEBHOOK_NAME

Trigger:
  - Name: $TRIGGER_NAME

EOF

echo "✅ Resource summary written to: $RESOURCE_SUMMARY_FILE"
echo "🎉 All resources created successfully."