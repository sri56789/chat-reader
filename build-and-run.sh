#!/bin/bash
set -e

echo "=========================================="
echo "Building Single Application"
echo "=========================================="

# Step 1: Build frontend
echo ""
echo "Step 1: Building Next.js frontend..."
cd frontend

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed. Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm is not installed. Please install npm."
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/next" ]; then
    echo "Installing npm dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo "ERROR: npm install failed!"
        exit 1
    fi
fi

echo "Building frontend (this may take a minute)..."
npm run build

if [ ! -d "out" ]; then
    echo "ERROR: Frontend build failed! 'out' directory not found."
    exit 1
fi

echo "✓ Frontend built successfully"

# Step 2: Copy to backend resources
echo ""
echo "Step 2: Copying frontend to backend resources..."
cd ..
mkdir -p backend/src/main/resources/static

# Clean previous build
rm -rf backend/src/main/resources/static/*

# Copy new build
cp -r frontend/out/* backend/src/main/resources/static/

echo "✓ Frontend files copied to backend"

# Step 3: Build Spring Boot
echo ""
echo "Step 3: Building Spring Boot application..."
cd backend
mvn clean package -DskipTests

if [ ! -f "target/pdf-chatbot-0.0.1.jar" ]; then
    echo "ERROR: Spring Boot build failed!"
    exit 1
fi

echo "✓ Spring Boot built successfully"

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Starting application..."
echo "Access at: http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop"
echo "=========================================="
echo ""

# Run the application
java -jar target/pdf-chatbot-0.0.1.jar


