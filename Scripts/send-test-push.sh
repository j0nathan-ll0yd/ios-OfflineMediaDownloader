#!/bin/bash
# Send test push notification to iOS Simulator
#
# Usage: ./Scripts/send-test-push.sh [metadata|download-ready] [device-id]
#
# Examples:
#   ./Scripts/send-test-push.sh metadata                    # Use booted simulator
#   ./Scripts/send-test-push.sh download-ready              # Use booted simulator
#   ./Scripts/send-test-push.sh metadata booted             # Explicit booted
#   ./Scripts/send-test-push.sh metadata 12345-ABCD         # Specific device UDID

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_ROOT="$(dirname "$SCRIPT_DIR")"
FIXTURES_DIR="$IOS_ROOT/OfflineMediaDownloaderTests/Fixtures"

# Default values
NOTIFICATION_TYPE="${1:-metadata}"
DEVICE_ID="${2:-booted}"
BUNDLE_ID="com.example.OfflineMediaDownloader"

# Select the appropriate .apns file
case "$NOTIFICATION_TYPE" in
  metadata)
    APNS_FILE="$FIXTURES_DIR/push-metadata.apns"
    ;;
  download-ready|download)
    APNS_FILE="$FIXTURES_DIR/push-download-ready.apns"
    ;;
  *)
    echo "Error: Unknown notification type '$NOTIFICATION_TYPE'"
    echo "Usage: $0 [metadata|download-ready] [device-id]"
    exit 1
    ;;
esac

# Check if file exists
if [ ! -f "$APNS_FILE" ]; then
  echo "Error: Push notification fixture not found: $APNS_FILE"
  echo "Run ./Scripts/sync-backend-fixtures.sh to create fixtures"
  exit 1
fi

echo "Sending $NOTIFICATION_TYPE push notification..."
echo "  Device: $DEVICE_ID"
echo "  Bundle: $BUNDLE_ID"
echo "  File: $APNS_FILE"
echo ""

# Check if simulator is booted
if [ "$DEVICE_ID" = "booted" ]; then
  BOOTED_DEVICES=$(xcrun simctl list devices | grep "Booted" | wc -l | tr -d ' ')
  if [ "$BOOTED_DEVICES" -eq 0 ]; then
    echo "Error: No simulator is currently booted"
    echo "Start a simulator first: open -a Simulator"
    exit 1
  fi
fi

# Send the push notification
xcrun simctl push "$DEVICE_ID" "$BUNDLE_ID" "$APNS_FILE"

echo ""
echo "Push notification sent successfully!"
echo ""
echo "Tip: Make sure the app is installed and has push permissions enabled."
echo "     The app should be in the background to see the notification banner."
