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
gcloud services enable artifactregistry.googleapis.com --quiet
gcloud services enable containerregistry.googleapis.com --quiet 2>/dev/null || true

# Use Artifact Registry (recommended) or fallback to Container Registry
REPO_LOCATION="${REGION}"
REPO_NAME="docker-repo"

echo ""
echo "Step 2: Setting up Artifact Registry..."
# Check if repository exists, create if not
if ! gcloud artifacts repositories describe $REPO_NAME \
    --location=$REPO_LOCATION \
    --repository-format=docker &>/dev/null 2>&1; then
  echo "Creating Artifact Registry repository..."
  gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REPO_LOCATION \
    --description="Docker repository for PDF Chatbot" \
    --quiet || {
    echo "  Warning: Failed to create Artifact Registry repository"
    echo "  Will try to use Container Registry (gcr.io) instead"
    USE_GCR=true
  }
else
  echo "Artifact Registry repository already exists"
  USE_GCR=false
fi

# Configure Docker authentication
echo ""
echo "Step 3: Configuring Docker authentication..."

if [ "$USE_GCR" != "true" ]; then
  gcloud auth configure-docker ${REPO_LOCATION}-docker.pkg.dev --quiet || {
    echo "  Warning: Artifact Registry auth failed, using GCR"
    USE_GCR=true
  }
fi

if [ "$USE_GCR" = "true" ]; then
  echo "  Using Container Registry (gcr.io)"
  gcloud auth configure-docker gcr.io --quiet || {
    echo "  ERROR: Failed to configure Docker authentication"
    exit 1
  }
else
  echo "  Using Artifact Registry"
  # Also configure GCR as fallback
  gcloud auth configure-docker gcr.io --quiet 2>/dev/null || true
fi

# Build Docker image
echo ""
echo "Step 4: Building Docker image..."
echo "  (This may take 5-10 minutes on first build)"
docker build -t pdf-chatbot:latest .

# Determine which registry to use and tag accordingly
if [ "$USE_GCR" = "true" ]; then
  IMAGE_NAME="gcr.io/$PROJECT_ID/pdf-chatbot:latest"
  docker tag pdf-chatbot:latest $IMAGE_NAME
else
  ARTIFACT_IMAGE="${REPO_LOCATION}-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/pdf-chatbot:latest"
  GCR_IMAGE="gcr.io/$PROJECT_ID/pdf-chatbot:latest"
  docker tag pdf-chatbot:latest $ARTIFACT_IMAGE
  docker tag pdf-chatbot:latest $GCR_IMAGE
fi

# Push image with retry logic
echo ""
echo "Step 5: Pushing image..."

# Function to push with retry
push_with_retry() {
  local image=$1
  local max_attempts=3
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    echo "  Attempt $attempt of $max_attempts: pushing $image"
    if docker push "$image" > /tmp/docker_push.log 2>&1; then
      echo "  ✓ Successfully pushed!"
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        echo "  ✗ Push failed, retrying in 5 seconds..."
        cat /tmp/docker_push.log | tail -5
        sleep 5
      else
        echo "  ✗ Push failed after $max_attempts attempts"
        cat /tmp/docker_push.log | tail -10
        return 1
      fi
    fi
    attempt=$((attempt + 1))
  done
}

# Try pushing to selected registry first
if [ "$USE_GCR" = "true" ]; then
  if push_with_retry "$IMAGE_NAME"; then
    echo "  ✓ Using Container Registry"
  else
    echo ""
    echo "=========================================="
    echo "ERROR: Failed to push image"
    echo "=========================================="
    exit 1
  fi
else
  # Try Artifact Registry first
  if push_with_retry "$ARTIFACT_IMAGE"; then
    IMAGE_NAME="$ARTIFACT_IMAGE"
    echo "  ✓ Using Artifact Registry"
  else
    echo ""
    echo "  Warning: Artifact Registry push failed, trying Container Registry..."
    if push_with_retry "$GCR_IMAGE"; then
      IMAGE_NAME="$GCR_IMAGE"
      echo "  ✓ Using Container Registry (fallback)"
    else
      echo ""
      echo "=========================================="
      echo "ERROR: Failed to push image to both registries"
      echo "=========================================="
      echo ""
      echo "Troubleshooting steps:"
      echo "  1. Check your internet connection"
      echo "  2. Verify you have proper permissions"
      echo "  3. Try authenticating again:"
      echo "     gcloud auth login"
      echo "     gcloud auth configure-docker ${REPO_LOCATION}-docker.pkg.dev"
      echo "     gcloud auth configure-docker gcr.io"
      echo "  4. Check APIs are enabled:"
      echo "     gcloud services list --enabled | grep -E 'artifactregistry|containerregistry'"
      echo "  5. Try using Cloud Build instead (handles push automatically):"
      echo "     gcloud builds submit --tag gcr.io/$PROJECT_ID/pdf-chatbot:latest ."
      echo "     gcloud run deploy pdf-chatbot --image gcr.io/$PROJECT_ID/pdf-chatbot:latest --region $REGION --allow-unauthenticated"
      echo ""
      echo "Alternative: Use Cloud Build for deployment:"
      echo "  gcloud builds submit --tag gcr.io/$PROJECT_ID/pdf-chatbot:latest ."
      echo "  Then deploy with: gcloud run deploy pdf-chatbot --image gcr.io/$PROJECT_ID/pdf-chatbot:latest --region $REGION"
      exit 1
    fi
  fi
fi

# Deploy to Cloud Run
echo ""
echo "Step 6: Deploying to Cloud Run..."
echo "  Using image: $IMAGE_NAME"
DEPLOY_CMD="gcloud run deploy pdf-chatbot \
  --image $IMAGE_NAME \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --max-instances 10"

if [ -n "$LLM_API_KEY" ]; then
  DEPLOY_CMD="$DEPLOY_CMD --set-env-vars LLM_API_KEY=$LLM_API_KEY"
fi

eval $DEPLOY_CMD

# Get URL
APP_URL=$(gcloud run services describe pdf-chatbot --region $REGION --format 'value(status.url)')

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Application URL: $APP_URL"
echo "Image: $IMAGE_NAME"
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
