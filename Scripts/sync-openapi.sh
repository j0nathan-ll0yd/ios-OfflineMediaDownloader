#!/bin/bash
# Sync OpenAPI spec from backend to iOS APITypes package
#
# Usage: ./Scripts/sync-openapi.sh
#
# This script copies the OpenAPI specification from the backend package
# to the iOS APITypes package, enabling type generation from the API contract.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_SPEC="$IOS_ROOT/../backend/docs/api/openapi.yaml"
IOS_SPEC="$IOS_ROOT/APITypes/Sources/APITypes/openapi.yaml"

if [ ! -f "$BACKEND_SPEC" ]; then
    echo "Error: Backend OpenAPI spec not found at $BACKEND_SPEC"
    exit 1
fi

cp "$BACKEND_SPEC" "$IOS_SPEC"
echo "OpenAPI spec synced from backend to iOS"
echo "  Source: $BACKEND_SPEC"
echo "  Target: $IOS_SPEC"
