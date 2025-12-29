#!/bin/bash
# Sync E2E test fixtures from backend to iOS test suite
#
# Usage: ./Scripts/sync-backend-fixtures.sh
#
# This script copies test fixtures from the backend E2E test infrastructure
# to the iOS test suite, enabling shared test data between frontend and backend.
#
# Requires: Backend PR #239 merged (E2E testing infrastructure)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_ROOT="$IOS_ROOT/../backend"
IOS_FIXTURES="$IOS_ROOT/OfflineMediaDownloaderTests/Fixtures"

# Ensure fixtures directory exists
mkdir -p "$IOS_FIXTURES"

echo "Syncing backend E2E fixtures to iOS..."
echo "  Backend root: $BACKEND_ROOT"
echo "  iOS fixtures: $IOS_FIXTURES"
echo ""

# Check if backend repo exists
if [ ! -d "$BACKEND_ROOT" ]; then
    echo "Warning: Backend repo not found at $BACKEND_ROOT"
    echo "Creating placeholder fixtures instead..."

    # Create placeholder fixtures that match expected backend format
    cat > "$IOS_FIXTURES/mock-siwa-tokens.json" << 'EOF'
{
  "description": "Mock Sign in with Apple tokens for LocalStack testing",
  "tokens": {
    "validUser": {
      "identityToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwIiwiZXhwIjoxNzM1Mzk4NDAwLCJpYXQiOjE3MzUzMTE5OTksInN1YiI6InRlc3QtdXNlci0wMDEiLCJlbWFpbCI6InRlc3RAcHJpdmF0ZXJlbGF5LmFwcGxlaWQuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImlzX3ByaXZhdGVfZW1haWwiOnRydWUsImF1dGhfdGltZSI6MTczNTMxMTk5OSwibm9uY2Vfc3VwcG9ydGVkIjp0cnVlfQ.mock-signature",
      "userId": "test-user-001",
      "email": "test@privaterelay.appleid.com"
    },
    "newUser": {
      "identityToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwIiwiZXhwIjoxNzM1Mzk4NDAwLCJpYXQiOjE3MzUzMTE5OTksInN1YiI6Im5ldy11c2VyLTAwMiIsImVtYWlsIjoibmV3QHByaXZhdGVyZWxheS5hcHBsZWlkLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJpc19wcml2YXRlX2VtYWlsIjp0cnVlLCJhdXRoX3RpbWUiOjE3MzUzMTE5OTksIm5vbmNlX3N1cHBvcnRlZCI6dHJ1ZX0.mock-signature",
      "userId": "new-user-002",
      "email": "new@privaterelay.appleid.com",
      "firstName": "Test",
      "lastName": "User"
    }
  }
}
EOF

    cat > "$IOS_FIXTURES/api-responses.json" << 'EOF'
{
  "description": "Expected API response formats for LocalStack testing",
  "responses": {
    "loginSuccess": {
      "body": {
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMDAxIiwiaWF0IjoxNzM1MzExOTk5LCJleHAiOjE3MzU0MDEyMDB9.test-signature",
        "expiresAt": "2025-01-01T00:00:00Z",
        "sessionId": "session-001",
        "userId": "test-user-001"
      }
    },
    "registerDeviceSuccess": {
      "body": {
        "endpointArn": "arn:aws:sns:us-east-1:000000000000:endpoint/APNS_SANDBOX/MyApp/test-endpoint-001"
      }
    },
    "fileListSuccess": {
      "body": {
        "contents": [
          {
            "fileId": "file-001",
            "key": "Test Video.mp4",
            "publishDate": "20241215",
            "size": 1024000,
            "url": "https://s3.localhost.localstack.cloud:4566/media-bucket/file-001.mp4",
            "status": "Downloaded",
            "title": "Test Video",
            "authorName": "Test Author"
          },
          {
            "fileId": "file-002",
            "key": "Pending Video.mp4",
            "publishDate": "20241220",
            "size": null,
            "url": null,
            "status": "Queued",
            "title": "Pending Video"
          }
        ],
        "keyCount": 2
      }
    },
    "addFileSuccess": {
      "body": {
        "status": "queued"
      }
    }
  }
}
EOF

    cat > "$IOS_FIXTURES/push-notifications.json" << 'EOF'
{
  "description": "Push notification payloads matching backend SNS format",
  "notifications": {
    "fileMetadata": {
      "aps": {
        "content-available": 1
      },
      "type": "metadata",
      "file": {
        "fileId": "file-003",
        "key": "New Video.mp4",
        "publishDate": "2024-12-28",
        "size": 2048000
      }
    },
    "downloadReady": {
      "aps": {
        "content-available": 1
      },
      "type": "download-ready",
      "fileId": "file-003",
      "key": "new-video.mp4",
      "url": "https://s3.localhost.localstack.cloud:4566/media-bucket/file-003.mp4",
      "size": 2048000
    }
  }
}
EOF

    cat > "$IOS_FIXTURES/localstack-config.json" << 'EOF'
{
  "description": "LocalStack configuration for iOS integration tests",
  "endpoints": {
    "apiGateway": "http://localhost:4566/restapis/test-api/local/_user_request_",
    "s3": "http://s3.localhost.localstack.cloud:4566",
    "sns": "http://localhost:4566"
  },
  "apiKey": "test-api-key-localstack",
  "region": "us-east-1"
}
EOF

    echo "Created placeholder fixtures:"
    ls -la "$IOS_FIXTURES"
    echo ""
    echo "Note: Replace these with actual backend fixtures once PR #239 is merged"
    exit 0
fi

# Backend repo exists - sync actual fixtures
echo "Syncing from backend E2E test fixtures..."

# Sync test fixtures from backend's E2E test infrastructure
# These paths will be valid once PR #239 is merged
BACKEND_FIXTURES="$BACKEND_ROOT/test/fixtures"
BACKEND_E2E_CLIENT="$BACKEND_ROOT/test/e2e/client"

if [ -d "$BACKEND_FIXTURES" ]; then
    echo "Copying fixture files..."
    cp -r "$BACKEND_FIXTURES"/*.json "$IOS_FIXTURES/" 2>/dev/null || true
    cp -r "$BACKEND_FIXTURES"/*.apns "$IOS_FIXTURES/" 2>/dev/null || true
fi

# Extract relevant test data from TypeScript utilities if they exist
if [ -f "$BACKEND_E2E_CLIENT/auth-client.ts" ]; then
    echo "Extracting mock SIWA token format from backend..."
    # The actual extraction would require parsing TypeScript
    # For now, just note the file exists
    echo "  Found: $BACKEND_E2E_CLIENT/auth-client.ts"
fi

echo ""
echo "Fixture sync complete!"
echo "Files in $IOS_FIXTURES:"
ls -la "$IOS_FIXTURES"
