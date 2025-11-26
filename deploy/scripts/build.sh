#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}=== SurfSense Docker Build Script ===${NC}"
echo ""

# Load environment variables
if [ -f "$DEPLOY_DIR/.env" ]; then
    export $(grep -v '^#' "$DEPLOY_DIR/.env" | grep -v '^$' | xargs)
fi

# Extract versions from source files
echo -e "${YELLOW}Extracting version numbers...${NC}"
BACKEND_VERSION=$(grep '^version = ' "$PROJECT_ROOT/surfsense_backend/pyproject.toml" | sed 's/version = "\(.*\)"/\1/')
FRONTEND_VERSION=$(grep '"version":' "$PROJECT_ROOT/surfsense_web/package.json" | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')

if [ -z "$BACKEND_VERSION" ]; then
    echo -e "${RED}ERROR: Could not extract backend version from pyproject.toml${NC}"
    exit 1
fi

if [ -z "$FRONTEND_VERSION" ]; then
    echo -e "${RED}ERROR: Could not extract frontend version from package.json${NC}"
    exit 1
fi

echo -e "  Backend Version:  ${GREEN}${BACKEND_VERSION}${NC}"
echo -e "  Frontend Version: ${GREEN}${FRONTEND_VERSION}${NC}"
echo ""

# Registry configuration
REGISTRY="${DOCKER_REGISTRY}"
if [ -z "$REGISTRY" ]; then
    echo -e "${RED}ERROR: DOCKER_REGISTRY environment variable is not set${NC}"
    echo "Please set DOCKER_REGISTRY in deploy/.env"
    exit 1
fi
echo -e "${YELLOW}Registry: ${REGISTRY}${NC}"
echo ""

# Build target (default: both)
BUILD_TARGET="${1:-both}"

# Optional postfix for tags
POSTFIX="${2:-}"

if [ -n "$POSTFIX" ]; then
    echo -e "${YELLOW}Tag Postfix: ${POSTFIX}${NC}"
    BACKEND_TAG="${BACKEND_VERSION}-${POSTFIX}"
    FRONTEND_TAG="${FRONTEND_VERSION}-${POSTFIX}"
else
    BACKEND_TAG="${BACKEND_VERSION}"
    FRONTEND_TAG="${FRONTEND_VERSION}"
fi
echo ""

# Function to build backend
build_backend() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Building Backend Image...${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    docker build \
        -t "${REGISTRY}/surfsense-backend:${BACKEND_TAG}" \
        -t "${REGISTRY}/surfsense-backend:latest" \
        -f "$PROJECT_ROOT/surfsense_backend/Dockerfile" \
        "$PROJECT_ROOT/surfsense_backend"

    echo ""
    echo -e "${GREEN}✓ Backend image built successfully!${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-backend:${BACKEND_TAG}${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-backend:latest${NC}"
    echo ""
}

# Function to build frontend
build_frontend() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Building Frontend Image...${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Read NEXT_PUBLIC variables from .env
    NEXT_PUBLIC_BACKEND_URL="${NEXT_PUBLIC_FASTAPI_BACKEND_URL}"
    if [ -z "$NEXT_PUBLIC_BACKEND_URL" ]; then
        echo -e "${RED}ERROR: NEXT_PUBLIC_FASTAPI_BACKEND_URL environment variable is not set${NC}"
        echo "Please set NEXT_PUBLIC_FASTAPI_BACKEND_URL in deploy/.env"
        exit 1
    fi
    NEXT_PUBLIC_AUTH_TYPE="${NEXT_PUBLIC_FASTAPI_BACKEND_AUTH_TYPE:-LOCAL}"
    NEXT_PUBLIC_ETL="${NEXT_PUBLIC_ETL_SERVICE:-DOCLING}"

    echo -e "${YELLOW}Build Arguments:${NC}"
    echo -e "  NEXT_PUBLIC_FASTAPI_BACKEND_URL: ${NEXT_PUBLIC_BACKEND_URL}"
    echo -e "  NEXT_PUBLIC_FASTAPI_BACKEND_AUTH_TYPE: ${NEXT_PUBLIC_AUTH_TYPE}"
    echo -e "  NEXT_PUBLIC_ETL_SERVICE: ${NEXT_PUBLIC_ETL}"
    echo ""

    docker build \
        --build-arg NEXT_PUBLIC_FASTAPI_BACKEND_URL="${NEXT_PUBLIC_BACKEND_URL}" \
        --build-arg NEXT_PUBLIC_FASTAPI_BACKEND_AUTH_TYPE="${NEXT_PUBLIC_AUTH_TYPE}" \
        --build-arg NEXT_PUBLIC_ETL_SERVICE="${NEXT_PUBLIC_ETL}" \
        -t "${REGISTRY}/surfsense-frontend:${FRONTEND_TAG}" \
        -t "${REGISTRY}/surfsense-frontend:latest" \
        -f "$PROJECT_ROOT/surfsense_web/Dockerfile" \
        "$PROJECT_ROOT/surfsense_web"

    echo ""
    echo -e "${GREEN}✓ Frontend image built successfully!${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-frontend:${FRONTEND_TAG}${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-frontend:latest${NC}"
    echo ""
}

# Validate build target
case "$BUILD_TARGET" in
    backend|frontend|both)
        ;;
    *)
        echo -e "${RED}ERROR: Invalid build target: $BUILD_TARGET${NC}"
        echo ""
        echo "Usage: $0 [backend|frontend|both] [postfix]"
        echo ""
        echo "Examples:"
        echo "  $0                    # Build both services"
        echo "  $0 backend            # Build backend only"
        echo "  $0 frontend           # Build frontend only"
        echo "  $0 both rc1           # Build both with -rc1 postfix"
        echo "  $0 backend hotfix     # Build backend with -hotfix postfix"
        echo ""
        exit 1
        ;;
esac

# Build based on target
START_TIME=$(date +%s)

if [ "$BUILD_TARGET" = "backend" ] || [ "$BUILD_TARGET" = "both" ]; then
    build_backend
fi

if [ "$BUILD_TARGET" = "frontend" ] || [ "$BUILD_TARGET" = "both" ]; then
    build_frontend
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Build Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Build Time: ${DURATION}s"
echo ""

# Ask if user wants to push
echo -e "${YELLOW}Do you want to push the images to the registry? (y/n)${NC}"
read -r PUSH_ANSWER

if [ "$PUSH_ANSWER" = "y" ] || [ "$PUSH_ANSWER" = "Y" ]; then
    echo ""
    echo -e "${BLUE}Calling push script...${NC}"
    echo ""
    "$SCRIPT_DIR/push.sh" "$BUILD_TARGET" "$POSTFIX"
else
    echo ""
    echo -e "${BLUE}Skipping push. You can push later with:${NC}"
    if [ -n "$POSTFIX" ]; then
        echo -e "  ${SCRIPT_DIR}/push.sh $BUILD_TARGET $POSTFIX"
    else
        echo -e "  ${SCRIPT_DIR}/push.sh $BUILD_TARGET"
    fi
    echo ""
fi
