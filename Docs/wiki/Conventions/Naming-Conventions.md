# Naming Conventions

## Quick Reference
- **When to use**: All code in this project
- **Enforcement**: Required
- **Impact if violated**: Medium - Code review rejection

---

## The Rules

### Type Names (PascalCase)
All type definitions use PascalCase:

```swift
// Structs
struct UserData { }
struct FileListFeature { }
struct FileCellFeature { }

// Enums
enum LoginStatus { }
enum RegistrationStatus { }

// Protocols
protocol Authenticatable { }

// Type aliases
typealias FileResponse = APIResponse<FileList>
```

### Variables & Functions (camelCase)
All variables, properties, and functions use camelCase:

```swift
// Properties
var isLoading: Bool
var downloadProgress: Double
var errorMessage: String?

// Functions
func determineLoginStatus() async -> LoginStatus
func formatFileSize(_ bytes: Int) -> String

// Parameters
func downloadFile(url: URL, expectedSize: Int64)
```

### Constants
- **Local constants**: camelCase
- **Global constants**: camelCase or SCREAMING_SNAKE_CASE for truly global config

```swift
// Local constants (camelCase)
let dismissThreshold: CGFloat = 150
let maxRetries = 3

// Global config (either style acceptable)
let apiKey = "..."
let API_VERSION = "v1"
```

### TCA-Specific Naming

#### Features
Feature names end with `Feature`:
```swift
struct RootFeature { }
struct LoginFeature { }
struct FileListFeature { }
struct FileCellFeature { }
```

#### Actions
Actions use descriptive camelCase, often verb-based:
```swift
enum Action {
  // User interactions: noun + "Tapped" or "Changed"
  case loginButtonTapped
  case downloadButtonTapped
  case valueChanged(String)

  // Lifecycle
  case onAppear
  case onDisappear

  // Async responses: noun + "Response" or verb past tense
  case loginResponse(Result<LoginResponse, Error>)
  case filesLoaded([File])
  case downloadCompleted(URL)

  // Delegate actions
  case delegate(Delegate)
}
```

#### Delegate Actions
Delegate action names describe what happened:
```swift
enum Delegate: Equatable {
  case loginCompleted
  case registrationCompleted
  case authenticationRequired
  case fileDeleted(File)
  case playFile(File)
}
```

#### Cancel IDs
Cancel IDs use short, descriptive names:
```swift
private enum CancelID {
  case download
  case signIn
  case fetch
  case refresh
}
```

#### Dependency Clients
Client names end with `Client`:
```swift
struct ServerClient { }
struct KeychainClient { }
struct AuthenticationClient { }
struct CoreDataClient { }
struct DownloadClient { }
struct FileClient { }
```

### File Naming

| Type | Convention | Example |
|------|------------|---------|
| Feature + View | `FeatureNameView.swift` | `LoginView.swift`, `FileListView.swift` |
| Feature only | `FeatureName.swift` | `MainFeature.swift` |
| Dependency | `ClientName.swift` | `ServerClient.swift` |
| Model | `ModelName.swift` | `File.swift`, `UserData.swift` |
| Extension | `TypeName+Category.swift` | `String+YouTube.swift` |

---

## Examples

### Correct
```swift
@Reducer
struct FileListFeature {
  @ObservableState
  struct State: Equatable {
    var files: IdentifiedArrayOf<FileCellFeature.State> = []
    var isLoading: Bool = false
    var errorMessage: String?
  }

  enum Action {
    case onAppear
    case refreshButtonTapped
    case filesLoaded([File])
    case delegate(Delegate)

    enum Delegate: Equatable {
      case authenticationRequired
    }
  }

  @Dependency(\.serverClient) var serverClient

  private enum CancelID { case fetch }
}
```

### Incorrect
```swift
// ❌ Wrong: Various naming violations
@Reducer
struct file_list {  // Should be PascalCase: FileList
  struct state {    // Should be PascalCase: State
    var Files: [File] = []  // Should be camelCase: files
    var IsLoading: Bool = false  // Should be camelCase: isLoading
  }

  enum action {  // Should be PascalCase: Action
    case OnAppear  // Should be camelCase: onAppear
    case REFRESH   // Should be camelCase: refresh or refreshButtonTapped
  }
}
```

---

## Rationale

Consistent naming improves:
- **Readability**: Predictable patterns reduce cognitive load
- **Searchability**: Find types vs instances easily
- **Swift conventions**: Matches Apple's API design guidelines
- **TCA conventions**: Matches Point-Free's established patterns

---

## Related Patterns
- [Action-Naming.md](../TCA/Action-Naming.md)
- [Dependency-Client-Design.md](../TCA/Dependency-Client-Design.md)
- [File-Organization.md](File-Organization.md)
