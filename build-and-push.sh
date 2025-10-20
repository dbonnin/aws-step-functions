#!/bin/bash

# Docker Build and Push Script
# Builds the step-functions-demo service and pushes to Docker Hub

set -e  # Exit on any error

# Configuration
DOCKER_USERNAME="dbonnin"
IMAGE_NAME="step-functions-demo"
SERVICE_DIR="example-service"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Docker Build and Push Script${NC}"
echo "=================================="

# Check if we're in the right directory
if [ ! -d "$SERVICE_DIR" ]; then
    echo -e "${RED}❌ Error: $SERVICE_DIR directory not found!${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "$SERVICE_DIR/Dockerfile" ]; then
    echo -e "${RED}❌ Error: Dockerfile not found in $SERVICE_DIR!${NC}"
    exit 1
fi

# Get version tag (default to 'latest' if no argument provided)
VERSION_TAG=${1:-latest}
FULL_IMAGE_TAG="$DOCKER_USERNAME/$IMAGE_NAME:$VERSION_TAG"

echo -e "${YELLOW}📋 Build Configuration:${NC}"
echo "  • Service Directory: $SERVICE_DIR"
echo "  • Image Name: $IMAGE_NAME"
echo "  • Full Tag: $FULL_IMAGE_TAG"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running!${NC}"
    echo "Please start Docker and try again."
    exit 1
fi

# Check if user is logged into Docker Hub
echo -e "${BLUE}🔐 Checking Docker Hub authentication...${NC}"
if ! docker info | grep -q "Username: $DOCKER_USERNAME"; then
    echo -e "${YELLOW}⚠️  Not logged into Docker Hub as $DOCKER_USERNAME${NC}"
    echo "Please log in first:"
    echo "  docker login"
    read -p "Press Enter after logging in, or Ctrl+C to exit..."
fi

# Build the Docker image
echo -e "${BLUE}🔨 Building Docker image...${NC}"
echo "Command: docker build -t $FULL_IMAGE_TAG $SERVICE_DIR"
docker build -t "$FULL_IMAGE_TAG" "$SERVICE_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Tag as latest if building a specific version
if [ "$VERSION_TAG" != "latest" ]; then
    LATEST_TAG="$DOCKER_USERNAME/$IMAGE_NAME:latest"
    echo -e "${BLUE}🏷️  Tagging as latest...${NC}"
    docker tag "$FULL_IMAGE_TAG" "$LATEST_TAG"
fi

# Push the image
echo -e "${BLUE}📤 Pushing to Docker Hub...${NC}"
docker push "$FULL_IMAGE_TAG"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Push successful!${NC}"
else
    echo -e "${RED}❌ Push failed!${NC}"
    exit 1
fi

# Also push latest tag if we tagged it
if [ "$VERSION_TAG" != "latest" ]; then
    echo -e "${BLUE}📤 Pushing latest tag...${NC}"
    docker push "$LATEST_TAG"
fi

echo ""
echo -e "${GREEN}🎉 Docker image built and pushed successfully!${NC}"
echo "=================================="
echo -e "${YELLOW}📋 Image Details:${NC}"
echo "  • Repository: https://hub.docker.com/r/$DOCKER_USERNAME/$IMAGE_NAME"
echo "  • Tag: $FULL_IMAGE_TAG"
if [ "$VERSION_TAG" != "latest" ]; then
    echo "  • Also tagged as: $LATEST_TAG"
fi
echo ""
echo -e "${YELLOW}🚀 Usage in infrastructure:${NC}"
echo "  The image is now available for deployment in your Terraform configuration."
echo "  Current image reference: $DOCKER_USERNAME/$IMAGE_NAME:latest"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "  • Build with version: ./build-and-push.sh v1.0.0"
echo "  • Build latest: ./build-and-push.sh"
echo "  • View local images: docker images | grep $IMAGE_NAME"