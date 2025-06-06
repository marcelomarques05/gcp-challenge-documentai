#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_help() {
  echo "Usage: $(basename "$0") --summary-file <file>"
  echo "Deletes all resources listed in the summary file generated by the provisioning script."
  exit 1
}

# Parse args
SUMMARY_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-file)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      ;;
    *)
      echo "Unknown argument: $1"
      print_help
      ;;
  esac
done

if [[ -z "$SUMMARY_FILE" || ! -f "$SUMMARY_FILE" ]]; then
  echo "❌ Summary file not provided or does not exist."
  print_help
fi

# Extract values from summary file
PROJECT_ID=$(grep '^Project ID:' "$SUMMARY_FILE" | awk '{print $3}')
PROJECT_NUMBER=$(grep '^Project Number:' "$SUMMARY_FILE" | awk '{print $3}')
REGION=$(grep '^Region:' "$SUMMARY_FILE" | awk '{print $2}')
LOCATION=$(grep '^Location:' "$SUMMARY_FILE" | awk '{print $2}')
MAIN_BUCKET=$(grep -A1 'Storage Buckets:' "$SUMMARY_FILE" | head -n2 | tail -n1 | awk '{print $2}')
DOCS_BUCKET=$(grep -A2 'Storage Buckets:' "$SUMMARY_FILE" | tail -n1 | awk '{print $2}')
ARTIFACT_REPO_NAME=$(grep -A1 'Artifact Registry:' "$SUMMARY_FILE" | tail -n1 | awk '{print $2}')
WEBHOOK_SA=$(grep -A2 'Service Accounts:' "$SUMMARY_FILE" | grep -m1 '@' | awk '{print $2}')
TRIGGER_SA=$(grep -A2 'Service Accounts:' "$SUMMARY_FILE" | grep -m2 '@' | tail -n1 | awk '{print $2}')
OCR_PROCESSOR_NAME=$(grep -A1 'Document AI Processor:' "$SUMMARY_FILE" | head -n2 | tail -n1 | awk '{print $2}')
OCR_PROCESSOR_ID=$(grep -A1 'Document AI Processor:' "$SUMMARY_FILE" | head -n2 | tail -n1 | awk -F'[()]' '{print $2}' | sed 's/ID: //;s/)//')
DATASET_NAME=$(grep -A2 'BigQuery:' "$SUMMARY_FILE" | grep 'Dataset:' | awk '{print $3}')
TABLE_NAME=$(grep -A2 'BigQuery:' "$SUMMARY_FILE" | grep 'Table:' | awk '{print $3}')
WEBHOOK_NAME=$(grep -A1 'Cloud Function:' "$SUMMARY_FILE" | tail -n1 | awk '{print $3}')
TRIGGER_NAME=$(grep -A1 'Trigger:' "$SUMMARY_FILE" | tail -n1 | awk '{print $3}')

echo "🗑️ Starting resource deletion for project: $PROJECT_ID"

#---------------------------#
echo "🗑️ Deleting Cloud Function..."
#---------------------------#
if gcloud functions describe "$WEBHOOK_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud functions delete "$WEBHOOK_NAME" --region="$REGION" --quiet --project="$PROJECT_ID"
  echo "   - Cloud Function $WEBHOOK_NAME deleted."
else
  echo "   - Cloud Function $WEBHOOK_NAME does not exist, skipping."
fi
echo "✅ Cloud Function deletion done."

#---------------------------#
echo "🗑️ Deleting Artifact Registry repository..."
#---------------------------#
if gcloud artifacts repositories describe "$ARTIFACT_REPO_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud artifacts repositories delete "$ARTIFACT_REPO_NAME" --location="$REGION" --quiet --project="$PROJECT_ID"
  echo "   - Artifact Registry repo $ARTIFACT_REPO_NAME deleted."
else
  echo "   - Artifact Registry repo $ARTIFACT_REPO_NAME does not exist, skipping."
fi
echo "✅ Artifact Registry deletion done."

#---------------------------#
echo "🗑️ Deleting GCS buckets..."
#---------------------------#
for BUCKET in "$MAIN_BUCKET" "$DOCS_BUCKET"; do
  if gsutil ls -b "gs://$BUCKET" >/dev/null 2>&1; then
    gsutil -m rm -r "gs://$BUCKET"
    echo "   - Bucket $BUCKET deleted."
  else
    echo "   - Bucket $BUCKET does not exist, skipping."
  fi
done
echo "✅ GCS bucket deletion done."

#---------------------------#
echo "🗑️ Deleting BigQuery table and dataset..."
#---------------------------#
# Check and delete table
if bq show --format=prettyjson "$PROJECT_ID:$DATASET_NAME.$TABLE_NAME" >/dev/null 2>&1; then
  bq rm -f -t "$PROJECT_ID:$DATASET_NAME.$TABLE_NAME" >/dev/null 2>&1
  echo "   - Table $TABLE_NAME deleted."
else
  echo "   - Table $TABLE_NAME does not exist, skipping."
fi

# Check and delete dataset
if bq show --format=prettyjson "$PROJECT_ID:$DATASET_NAME" >/dev/null 2>&1; then
  bq rm -f -d "$PROJECT_ID:$DATASET_NAME" >/dev/null 2>&1
  echo "   - Dataset $DATASET_NAME deleted."
else
  echo "   - Dataset $DATASET_NAME does not exist, skipping."
fi
echo "✅ BigQuery deletion done."

#---------------------------#
echo "🗑️ Deleting Document AI Processor..."
#---------------------------#
if [[ -n "$OCR_PROCESSOR_ID" ]]; then
  PROC_STATUS=$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors/${OCR_PROCESSOR_ID}")
  if [[ "$PROC_STATUS" != *"notFound"* ]]; then
    curl -s -X DELETE \
      -H "Authorization: Bearer $(gcloud auth print-access-token)" \
      "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors/${OCR_PROCESSOR_ID}" >/dev/null 2>&1
    echo "   - Document AI Processor $OCR_PROCESSOR_ID deleted."
  else
    echo "   - Document AI Processor $OCR_PROCESSOR_ID does not exist, skipping."
  fi
else
  echo "   - No Document AI Processor ID found, skipping."
fi
echo "✅ Document AI Processor deletion done."

#---------------------------#
echo "🗑️ Deleting service accounts..."
#---------------------------#
for SA in "$WEBHOOK_SA" "$TRIGGER_SA"; do
  if [[ -n "$SA" ]] && gcloud iam service-accounts describe "$SA" --project="$PROJECT_ID" >/dev/null 2>&1; then
    gcloud iam service-accounts delete "$SA" --quiet --project="$PROJECT_ID"
    echo "   - Service account $SA deleted."
  else
    echo "   - Service account $SA does not exist, skipping."
  fi
done
echo "✅ Service account deletion done."

echo "✅ All resources deleted (as listed in $SUMMARY_FILE)."