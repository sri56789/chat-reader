#!/bin/bash
set -e

echo "=========================================="
echo "Deploying to Google Cloud Run"
echo "=========================================="

# Get project ID - support both env var and interactive
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=${GCP_PROJECT_ID:-""}
fi

if [ -z "$PROJECT_ID" ]; then
  CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
  if [ -z "$CURRENT_PROJECT" ]; then
    read -p "Enter your GCP Project ID: " PROJECT_ID
  else
    echo "Using current project: $CURRENT_PROJECT"
    read -p "Press Enter to continue or type a different Project ID: " INPUT
    PROJECT_ID=${INPUT:-$CURRENT_PROJECT}
  fi
fi

export REGION=${REGION:-${GCP_REGION:-us-central1}}
export LLM_API_KEY=${LLM_API_KEY:-""}

echo ""
echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  LLM API Key: ${LLM_API_KEY:+***SET***} ${LLM_API_KEY:-NOT SET (will use fallback)}"
echo ""

# Set project
gcloud config set project $PROJECT_ID

# Enable APIs
echo "Step 1: Enabling required APIs..."
gcloud services enable run.googleapis.com --quiet
gcloud services enable containerregistry.googleapis.com --quiet

# Configure Docker
echo ""
echo "Step 2: Configuring Docker authentication..."
gcloud auth configure-docker --quiet

# Build Docker image
echo ""
echo "Step 3: Building Docker image..."
echo "  (This may take 5-10 minutes on first build)"
docker build -t gcr.io/$PROJECT_ID/pdf-chatbot:latest .

# Push image
echo ""
echo "Step 4: Pushing image to Container Registry..."
docker push gcr.io/$PROJECT_ID/pdf-chatbot:latest

# Deploy to Cloud Run
echo ""
echo "Step 5: Deploying to Cloud Run..."
if [ -z "$LLM_API_KEY" ]; then
  gcloud run deploy pdf-chatbot \
    --image gcr.io/$PROJECT_ID/pdf-chatbot:latest \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 300 \
    --max-instances 10
else
  gcloud run deploy pdf-chatbot \
    --image gcr.io/$PROJECT_ID/pdf-chatbot:latest \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 300 \
    --max-instances 10 \
    --set-env-vars LLM_API_KEY=$LLM_API_KEY
fi

# Get URL
APP_URL=$(gcloud run services describe pdf-chatbot --region $REGION --format 'value(status.url)')

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Application URL: $APP_URL"
echo ""
echo "Your single Spring Boot app is now live!"
echo "It serves both UI and API from one endpoint."
echo ""
echo "Next steps:"
echo "  1. Open the URL in your browser"
echo "  2. Click 'Reload PDFs' after uploading PDFs"
echo "  3. Start asking questions!"
echo ""
echo "To view logs:"
echo "  gcloud run services logs read pdf-chatbot --region $REGION"
echo "=========================================="
