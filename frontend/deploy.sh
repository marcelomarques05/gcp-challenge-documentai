#!/bin/bash

# Check required environment variables
REQUIRED_VARS=("PROJECT_ID" "BUCKET_NAME" "DATASET_NAME" "TABLE_NAME" "REGION" "FRONTEND_SA")
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo "Error: Environment variable $var is not set."
    exit 1
  fi
done

gcloud builds submit --tag gcr.io/${PROJECT_ID}/file-processor-frontend
gcloud run deploy file-processor-frontend \
  --image gcr.io/${PROJECT_ID}/file-processor-frontend \
  --set-env-vars PROJECT_ID=${PROJECT_ID},BUCKET_NAME=${BUCKET_NAME},DATASET_NAME=${DATASET_NAME},TABLE_NAME=${TABLE_NAME} \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated \
  --service-account=${FRONTEND_SA}
