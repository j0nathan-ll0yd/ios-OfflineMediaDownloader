# Keychain Storage (Valet)

## Quick Reference
- **When to use**: Storing sensitive data (tokens, user identity)
- **Enforcement**: Required for credentials
- **Impact if violated**: Critical - Security vulnerability

---

## The Rule

Use KeychainClient (backed by Valet) for all sensitive data storage. Never store tokens or credentials in UserDefaults or files.

---

## Valet Configuration

### Setup
```swift
import Valet

// Standard keychain
let valet = Valet.valet(
  with: Identifier(nonEmpty: "com.yourapp.keychain")!,
  accessibility: .whenUnlocked
)

// Secure Enclave (biometric protected)
let secureValet = SecureEnclaveValet.valet(
  with: Identifier(nonEmpty: "com.yourapp.secure")!,
  accessControl: .userPresence
)
```

### Accessibility Options
| Option | Description |
|--------|-------------|
| `.whenUnlocked` | Available when device unlocked |
| `.afterFirstUnlock` | Available after first unlock since boot |
| `.whenUnlockedThisDeviceOnly` | Not backed up, device-specific |

---

## KeychainClient Interface

```swift
@DependencyClient
struct KeychainClient {
  // User data
  var getUserData: @Sendable () async throws -> UserData
  var setUserData: @Sendable (_ userData: UserData) async throws -> Void
  var deleteUserData: @Sendable () async throws -> Void

  // JWT Token
  var getJwtToken: @Sendable () async throws -> String?
  var setJwtToken: @Sendable (_ token: String) async throws -> Void
  var deleteJwtToken: @Sendable () async throws -> Void

  // Device registration
  var getDeviceData: @Sendable () async throws -> DeviceData?
  var setDeviceData: @Sendable (_ deviceData: DeviceData) async throws -> Void
  var deleteDeviceData: @Sendable () async throws -> Void

  // Quick checks
  var getUserIdentifier: @Sendable () async throws -> String?
}
```

---

## Keychain Keys

```swift
enum KeychainKeys {
  static let email = "email"
  static let firstName = "firstName"
  static let lastName = "lastName"
  static let identifier = "identifier"
  static let jwtToken = "jwtToken"
  static let endpointArn = "endpointArn"
}
```

---

## Implementation Patterns

### Storing Token
```swift
setJwtToken: { token in
  print("🔑 KeychainClient.setJwtToken called")
  try valet.setString(token, forKey: KeychainKeys.jwtToken)
}
```

### Retrieving Token
```swift
getJwtToken: {
  print("🔑 KeychainClient.getJwtToken called")
  do {
    return try valet.string(forKey: KeychainKeys.jwtToken)
  } catch {
    // errSecItemNotFound (-25300) means no token stored
    if (error as NSError).code == -25300 {
      return nil
    }
    throw error
  }
}
```

### Storing Complex Data (UserData)
```swift
setUserData: { userData in
  print("🔑 KeychainClient.setUserData called")
  try valet.setString(userData.email, forKey: KeychainKeys.email)
  try valet.setString(userData.firstName, forKey: KeychainKeys.firstName)
  try valet.setString(userData.lastName, forKey: KeychainKeys.lastName)
  try valet.setString(userData.identifier, forKey: KeychainKeys.identifier)
}
```

### Retrieving Complex Data
```swift
getUserData: {
  print("🔑 KeychainClient.getUserData called")
  let email = try valet.string(forKey: KeychainKeys.email)
  let firstName = try valet.string(forKey: KeychainKeys.firstName)
  let lastName = try valet.string(forKey: KeychainKeys.lastName)
  let identifier = try valet.string(forKey: KeychainKeys.identifier)

  return UserData(
    email: email,
    firstName: firstName,
    lastName: lastName,
    identifier: identifier
  )
}
```

### Deleting Data
```swift
deleteJwtToken: {
  print("🔑 KeychainClient.deleteJwtToken called")
  try valet.removeObject(forKey: KeychainKeys.jwtToken)
}

deleteUserData: {
  print("🔑 KeychainClient.deleteUserData called")
  try valet.removeObject(forKey: KeychainKeys.email)
  try valet.removeObject(forKey: KeychainKeys.firstName)
  try valet.removeObject(forKey: KeychainKeys.lastName)
  try valet.removeObject(forKey: KeychainKeys.identifier)
}
```

---

## Usage in Features

### Login Flow
```swift
case let .loginResponse(.success(response)):
  guard let token = response.body?.token else {
    return .send(.setError("No token received"))
  }

  return .run { send in
    try await keychainClient.setJwtToken(token)
    await send(.delegate(.loginCompleted))
  }
```

### Registration Flow
```swift
case let .registrationResponse(.success(response)):
  guard let token = response.body?.token else {
    return .send(.setError("No token received"))
  }

  return .run { [userData = state.pendingUserData] send in
    if let userData {
      try await keychainClient.setUserData(userData)
    }
    try await keychainClient.setJwtToken(token)
    await send(.delegate(.registrationCompleted))
  }
```

### Auth Check
```swift
case .checkAuthStatus:
  return .run { send in
    if let identifier = try await keychainClient.getUserIdentifier() {
      // User has registered before
      let status = try await authenticationClient.determineLoginStatus()
      await send(.authStatusChecked(status))
    } else {
      // New user
      await send(.authStatusChecked(.unauthenticated))
    }
  }
```

### Logout
```swift
case .logoutButtonTapped:
  return .run { send in
    try await keychainClient.deleteJwtToken()
    // Optionally keep user data for quick re-login
    await send(.delegate(.loggedOut))
  }
```

---

## Error Handling

### Missing Item
```swift
// Error code -25300 means item not found
if (error as NSError).code == -25300 {
  return nil  // Return nil instead of throwing
}
```

### Valet Errors
```swift
// Valet throws KeychainError for various failures
do {
  return try valet.string(forKey: key)
} catch KeychainError.itemNotFound {
  return nil
} catch KeychainError.couldNotAccessKeychain {
  print("⚠️ Keychain access denied")
  throw error
}
```

---

## Testing

```swift
withDependencies: {
  // Has token
  $0.keychainClient.getJwtToken = { "test-token" }

  // No token
  $0.keychainClient.getJwtToken = { nil }

  // Has user
  $0.keychainClient.getUserIdentifier = { "test-user-id" }
  $0.keychainClient.getUserData = {
    UserData(email: "test@test.com", firstName: "Test", lastName: "User", identifier: "test-id")
  }

  // Storage
  $0.keychainClient.setJwtToken = { _ in }
  $0.keychainClient.setUserData = { _ in }
}
```

---

## Anti-Patterns

### Never store tokens in UserDefaults
```swift
// ❌ FORBIDDEN - Insecure
UserDefaults.standard.set(token, forKey: "token")

// ✅ CORRECT - Keychain storage
try await keychainClient.setJwtToken(token)
```

### Never log sensitive data
```swift
// ❌ FORBIDDEN
print("Token: \(token)")

// ✅ CORRECT - Log existence only
let tokenPreview = String(token.prefix(20)) + "..."
print("🔑 Token stored (\(token.count) chars)")
```

---

## Rationale

- **Security**: Keychain is encrypted and hardware-protected
- **Persistence**: Data survives app reinstall (optional)
- **Testability**: KeychainClient can be mocked

---

## Related Patterns
- [Dependency-Client-Design.md](../TCA/Dependency-Client-Design.md)
- [Environment-Configuration.md](Environment-Configuration.md)
