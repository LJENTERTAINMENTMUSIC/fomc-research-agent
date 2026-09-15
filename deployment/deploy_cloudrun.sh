#!/bin/bash
# ==============================================================
# Deploy FOMC Research Agent to Google Cloud Run
# (Replaces Vertex AI Agent Engine deployment)
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - GCP project with Cloud Run & BigQuery APIs enabled
#   - .env file configured
#
# Usage:
#   chmod +x deployment/deploy_cloudrun.sh
#   ./deployment/deploy_cloudrun.sh
# ==============================================================

set -euo pipefail

# Load env vars if .env exists
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
fi

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:?'GOOGLE_CLOUD_PROJECT not set. Check your .env file.'}"
REGION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
SERVICE_NAME="${CLOUD_RUN_SERVICE_NAME:-fomc-research-agent}"
IMAGE="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "============================================"
echo "  FOMC Research Agent — Cloud Run Deploy"
echo "============================================"
echo "Project:  ${PROJECT_ID}"
echo "Region:   ${REGION}"
echo "Service:  ${SERVICE_NAME}"
echo "Image:    ${IMAGE}"
echo "============================================"

# Enable required APIs
echo "\n[1/4] Enabling required APIs..."
gcloud services enable run.googleapis.com \
    cloudbuild.googleapis.com \
    bigquery.googleapis.com \
    aiplatform.googleapis.com \
    --project="${PROJECT_ID}" \
    --quiet

# Build container image
echo "\n[2/4] Building container image..."
gcloud builds submit \
    --tag "${IMAGE}" \
    --project="${PROJECT_ID}" \
    --quiet

# Deploy to Cloud Run
echo "\n[3/4] Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE}" \
    --platform managed \
    --region "${REGION}" \
    --allow-unauthenticated \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID}" \
    --set-env-vars "GOOGLE_CLOUD_LOCATION=${REGION}" \
    --set-env-vars "GOOGLE_CLOUD_BQ_DATASET=${GOOGLE_CLOUD_BQ_DATASET:-fomc_data}" \
    --set-env-vars "GOOGLE_GENAI_USE_VERTEXAI=${GOOGLE_GENAI_USE_VERTEXAI:-1}" \
    --memory 2Gi \
    --cpu 2 \
    --timeout 300 \
    --min-instances 0 \
    --max-instances 10 \
    --project="${PROJECT_ID}" \
    --quiet

# Get service URL
echo "\n[4/4] Verifying deployment..."
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --platform managed \
    --region "${REGION}" \
    --project="${PROJECT_ID}" \
    --format 'value(status.url)')

echo "\n============================================"
echo "  ✅ Deployment successful!"
echo "  URL: ${SERVICE_URL}"
echo "  Health: ${SERVICE_URL}/api/health"
echo "  API:    ${SERVICE_URL}/api/agent/run"
echo "============================================"

# Quick health check
echo "\nRunning health check..."
curl -s "${SERVICE_URL}/api/health" | python3 -m json.tool
