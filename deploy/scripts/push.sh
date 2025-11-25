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

echo -e "${BLUE}=== SurfSense Docker Push Script ===${NC}"
echo ""

# Load environment variables
if [ -f "$DEPLOY_DIR/.env" ]; then
    export $(grep -v '^#' "$DEPLOY_DIR/.env" | grep -v '^$' | xargs)
fi

# Extract versions
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
REGISTRY="${DOCKER_REGISTRY:-docker.at.nullest.com}"
echo -e "${YELLOW}Registry: ${REGISTRY}${NC}"
echo ""

# Push target (default: both)
PUSH_TARGET="${1:-both}"

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

# Function to push backend
push_backend() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Pushing Backend Images...${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    docker push "${REGISTRY}/surfsense-backend:${BACKEND_TAG}"
    docker push "${REGISTRY}/surfsense-backend:latest"

    echo ""
    echo -e "${GREEN}✓ Backend images pushed successfully!${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-backend:${BACKEND_TAG}${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-backend:latest${NC}"
    echo ""
}

# Function to push frontend
push_frontend() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Pushing Frontend Images...${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    docker push "${REGISTRY}/surfsense-frontend:${FRONTEND_TAG}"
    docker push "${REGISTRY}/surfsense-frontend:latest"

    echo ""
    echo -e "${GREEN}✓ Frontend images pushed successfully!${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-frontend:${FRONTEND_TAG}${NC}"
    echo -e "  ${BLUE}${REGISTRY}/surfsense-frontend:latest${NC}"
    echo ""
}

# Validate push target
case "$PUSH_TARGET" in
    backend|frontend|both)
        ;;
    *)
        echo -e "${RED}ERROR: Invalid push target: $PUSH_TARGET${NC}"
        echo ""
        echo "Usage: $0 [backend|frontend|both] [postfix]"
        echo ""
        echo "Examples:"
        echo "  $0                    # Push both services"
        echo "  $0 backend            # Push backend only"
        echo "  $0 frontend           # Push frontend only"
        echo "  $0 both rc1           # Push both with -rc1 postfix"
        echo "  $0 backend hotfix     # Push backend with -hotfix postfix"
        echo ""
        exit 1
        ;;
esac

# Push based on target
START_TIME=$(date +%s)

if [ "$PUSH_TARGET" = "backend" ] || [ "$PUSH_TARGET" = "both" ]; then
    push_backend
fi

if [ "$PUSH_TARGET" = "frontend" ] || [ "$PUSH_TARGET" = "both" ]; then
    push_frontend
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Push Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Push Time: ${DURATION}s"
echo ""
echo -e "${BLUE}Images available at:${NC}"

if [ "$PUSH_TARGET" = "backend" ] || [ "$PUSH_TARGET" = "both" ]; then
    echo -e "  ${REGISTRY}/surfsense-backend:${BACKEND_TAG}"
    echo -e "  ${REGISTRY}/surfsense-backend:latest"
fi

if [ "$PUSH_TARGET" = "frontend" ] || [ "$PUSH_TARGET" = "both" ]; then
    echo -e "  ${REGISTRY}/surfsense-frontend:${FRONTEND_TAG}"
    echo -e "  ${REGISTRY}/surfsense-frontend:latest"
fi

echo ""
