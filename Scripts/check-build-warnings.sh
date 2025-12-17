#!/bin/bash
# check-build-warnings.sh
# Builds the project and reports any warnings

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

echo "Building OfflineMediaDownloader..."
echo ""

# Find the first available simulator
SIMULATOR=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/' || echo "")

if [ -z "$SIMULATOR" ]; then
    echo -e "${RED}No iOS simulator found${NC}"
    exit 1
fi

SIMULATOR_NAME=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | sed 's/\s*(.*//;s/^\s*//')

echo "Using simulator: $SIMULATOR_NAME"
echo ""

# Run xcodebuild and capture output
BUILD_OUTPUT=$(xcodebuild \
    -project OfflineMediaDownloader.xcodeproj \
    -scheme OfflineMediaDownloader \
    -destination "platform=iOS Simulator,id=$SIMULATOR" \
    build 2>&1) || true

# Extract warnings (excluding metadata extraction warning which is harmless)
WARNINGS=$(echo "$BUILD_OUTPUT" | grep -E "warning:" | grep -v "Metadata extraction skipped" || true)

if [ -z "$WARNINGS" ]; then
    echo -e "${GREEN}Build completed with no warnings${NC}"
    exit 0
else
    WARNING_COUNT=$(echo "$WARNINGS" | wc -l | tr -d ' ')
    echo -e "${YELLOW}Build completed with $WARNING_COUNT warning(s):${NC}"
    echo ""
    echo "$WARNINGS"
    echo ""
    exit 1
fi
