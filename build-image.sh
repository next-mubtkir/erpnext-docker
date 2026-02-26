#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_JSON_PATH="${SCRIPT_DIR}/apps.json"

FRAPPE_VERSION="${FRAPPE_VERSION:-version-16}"
CUSTOM_IMAGE="${CUSTOM_IMAGE:-erpnext-custom}"
CUSTOM_TAG="${CUSTOM_TAG:-16}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build custom ERPNext image with apps from apps.json"
    echo ""
    echo "Options:"
    echo "  --no-cache    Build without cache"
    echo "  --push        Push image after build"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Environment variables:"
    echo "  FRAPPE_VERSION   Frappe version (default: version-16)"
    echo "  CUSTOM_IMAGE     Image name (default: erpnext-custom)"
    echo "  CUSTOM_TAG       Image tag (default: 16)"
    exit 0
}

NO_CACHE=""
PUSH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --push)
            PUSH="1"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [ ! -f "$APPS_JSON_PATH" ]; then
    echo "Error: apps.json not found at $APPS_JSON_PATH"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Building Custom ERPNext Image"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Image:   ${CUSTOM_IMAGE}:${CUSTOM_TAG}"
echo "Frappe:  ${FRAPPE_VERSION}"
echo ""
echo "Apps to install:"
jq -r '.[].url' "$APPS_JSON_PATH" | while read url; do
    echo "  - $url"
done
echo ""

APPS_JSON_BASE64=$(cat "$APPS_JSON_PATH" | base64)

docker build ${NO_CACHE} \
    --build-arg FRAPPE_BRANCH="${FRAPPE_VERSION}" \
    --build-arg APPS_JSON_BASE64="${APPS_JSON_BASE64}" \
    -t "${CUSTOM_IMAGE}:${CUSTOM_TAG}" \
    -f "${SCRIPT_DIR}/images/custom/Containerfile" \
    "${SCRIPT_DIR}"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Build Complete: ${CUSTOM_IMAGE}:${CUSTOM_TAG}"
echo "═══════════════════════════════════════════════════════════"

if [ -n "$PUSH" ]; then
    echo "Pushing image..."
    docker push "${CUSTOM_IMAGE}:${CUSTOM_TAG}"
    echo "Done!"
fi
