/// Combined authentication state representing both login and registration status.
///
/// This type provides a single source of truth for the user's authentication state,
/// determined on app launch by `AuthenticationClient.determineAuthState()`.
///
/// ## Registration Status
/// - `.registered`: User has completed Sign in with Apple at least once (Apple ID identifier stored in keychain)
/// - `.unregistered`: User has never completed Sign in with Apple with this app
///
/// ## Login Status
/// - `.authenticated`: User has valid credentials (Apple ID authorized + JWT token present)
/// - `.unauthenticated`: User needs to sign in (no token, revoked credentials, or expired session)
public struct AuthState: Equatable, Sendable {
  public let loginStatus: LoginStatus
  public let registrationStatus: RegistrationStatus

  public init(loginStatus: LoginStatus, registrationStatus: RegistrationStatus) {
    self.loginStatus = loginStatus
    self.registrationStatus = registrationStatus
  }

  /// User is authenticated and can access main app features
  public var isAuthenticated: Bool {
    loginStatus == .authenticated
  }

  /// User has previously registered with Sign in with Apple
  public var isRegistered: Bool {
    registrationStatus == .registered
  }
}
