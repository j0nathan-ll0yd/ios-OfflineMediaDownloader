# Environment Configuration

## Quick Reference
- **When to use**: Configuring API endpoints, keys, feature flags
- **Enforcement**: Required for deployment
- **Impact if violated**: Critical - App won't connect to backend

---

## Overview

Environment configuration uses Xcode xcconfig files to inject values at build time, keeping secrets out of source control.

---

## Configuration Files

### File Structure
```
OfflineMediaDownloaderCompostable/
├── Development.xcconfig    # Development settings (git-ignored)
├── Development.xcconfig.example  # Template for developers
└── Constants.swift         # Runtime access
```

### Development.xcconfig
```
// Development.xcconfig
// Copy from Development.xcconfig.example and fill in values

MEDIA_DOWNLOADER_API_KEY = your-api-gateway-key-here
MEDIA_DOWNLOADER_BASE_PATH = https$()/your-api-gateway.execute-api.region.amazonaws.com/prod/
```

### Important: URL Escaping
In xcconfig files, `//` must be escaped as `$()`:

```
// Wrong - breaks parsing
MEDIA_DOWNLOADER_BASE_PATH = https://example.com

// Correct - escaped
MEDIA_DOWNLOADER_BASE_PATH = https$()/example.com
```

---

## Environment Struct

### Definition
```swift
// Constants.swift or Environment.swift
enum Environment {
  static var apiKey: String {
    guard let key = Bundle.main.infoDictionary?["MEDIA_DOWNLOADER_API_KEY"] as? String,
          !key.isEmpty else {
      fatalError("MEDIA_DOWNLOADER_API_KEY not configured")
    }
    return key
  }

  static var basePath: String {
    guard let path = Bundle.main.infoDictionary?["MEDIA_DOWNLOADER_BASE_PATH"] as? String,
          !path.isEmpty else {
      fatalError("MEDIA_DOWNLOADER_BASE_PATH not configured")
    }
    return path
  }
}
```

### Info.plist Integration
Add to Info.plist:
```xml
<key>MEDIA_DOWNLOADER_API_KEY</key>
<string>$(MEDIA_DOWNLOADER_API_KEY)</string>
<key>MEDIA_DOWNLOADER_BASE_PATH</key>
<string>$(MEDIA_DOWNLOADER_BASE_PATH)</string>
```

---

## Usage in Code

### ServerClient
```swift
private func generateRequest(pathPart: String, method: String = "POST") async throws -> URLRequest {
  var urlComponents = URLComponents(string: Environment.basePath + pathPart)!
  urlComponents.queryItems = [
    URLQueryItem(name: "ApiKey", value: Environment.apiKey)
  ]

  var request = URLRequest(url: urlComponents.url!)
  request.httpMethod = method
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")

  // Add auth header if available
  if let token = try? await keychainClient.getJwtToken() {
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  }

  return request
}
```

---

## Xcode Configuration

### Project Settings
1. Open project settings
2. Go to "Info" tab
3. Under "Configurations", set:
   - Debug → Development.xcconfig
   - Release → Production.xcconfig (if needed)

### Scheme Settings
For different environments per scheme:
1. Edit scheme
2. Under "Run" → "Arguments"
3. Add environment variables (or use different configs)

---

## Multiple Environments

### Separate Config Files
```
Development.xcconfig   # Local development
Staging.xcconfig       # Staging server
Production.xcconfig    # Production server
```

### Environment-Specific Values
```
// Development.xcconfig
MEDIA_DOWNLOADER_BASE_PATH = https$()/dev-api.example.com/

// Production.xcconfig
MEDIA_DOWNLOADER_BASE_PATH = https$()/api.example.com/
```

---

## Git Configuration

### .gitignore
```gitignore
# Environment configuration
Development.xcconfig
Staging.xcconfig
Production.xcconfig

# Keep examples
!*.xcconfig.example
```

### Example File
```
// Development.xcconfig.example
// Copy this file to Development.xcconfig and fill in values

MEDIA_DOWNLOADER_API_KEY = your-api-key-here
MEDIA_DOWNLOADER_BASE_PATH = https$()/your-api.execute-api.region.amazonaws.com/prod/
```

---

## Validation

### Startup Check
```swift
// In App init or AppDelegate
func validateEnvironment() {
  #if DEBUG
  // Crash early if misconfigured
  _ = Environment.apiKey
  _ = Environment.basePath
  print("✅ Environment configured")
  print("📡 API Base: \(Environment.basePath)")
  #endif
}
```

### Conditional Compilation
```swift
#if DEBUG
print("🔧 Debug mode - API: \(Environment.basePath)")
#endif
```

---

## Build-Time Validation

### Build Phase Script
Add a "Run Script" build phase:

```bash
if [ -z "${MEDIA_DOWNLOADER_API_KEY}" ]; then
  echo "error: MEDIA_DOWNLOADER_API_KEY is not set. Copy Development.xcconfig.example to Development.xcconfig"
  exit 1
fi

if [ -z "${MEDIA_DOWNLOADER_BASE_PATH}" ]; then
  echo "error: MEDIA_DOWNLOADER_BASE_PATH is not set. Copy Development.xcconfig.example to Development.xcconfig"
  exit 1
fi
```

---

## Feature Flags

### Simple Flags
```
// Development.xcconfig
FEATURE_BACKGROUND_DOWNLOADS = YES
FEATURE_DEBUG_MENU = YES
```

```swift
enum Environment {
  static var backgroundDownloadsEnabled: Bool {
    Bundle.main.infoDictionary?["FEATURE_BACKGROUND_DOWNLOADS"] as? String == "YES"
  }
}
```

### Usage
```swift
if Environment.backgroundDownloadsEnabled {
  // Use background session
} else {
  // Use foreground session
}
```

---

## Testing

### Override in Tests
```swift
// Use mock environment in tests
enum TestEnvironment {
  static let apiKey = "test-api-key"
  static let basePath = "https://test.example.com/"
}
```

### Dependency Injection
```swift
// Instead of accessing Environment directly, inject values
struct ServerConfig {
  let apiKey: String
  let basePath: String
}

@DependencyClient
struct ServerClient {
  var config: ServerConfig
  // ...
}
```

---

## Anti-Patterns

### Never commit secrets
```swift
// ❌ FORBIDDEN - Hardcoded secrets
let apiKey = "sk_live_abc123"

// ✅ CORRECT - Environment variable
let apiKey = Environment.apiKey
```

### Never log secrets
```swift
// ❌ FORBIDDEN
print("API Key: \(Environment.apiKey)")

// ✅ CORRECT
print("API configured: \(Environment.apiKey.isEmpty ? "NO" : "YES")")
```

---

## Rationale

- **Security**: Secrets not in source control
- **Flexibility**: Different configs per environment
- **Team collaboration**: Each developer has own config

---

## Related Patterns
- [Dependency-Client-Design.md](../TCA/Dependency-Client-Design.md)
