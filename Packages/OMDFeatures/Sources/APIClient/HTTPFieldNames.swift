import HTTPTypes

/// Header names the app reads or writes that `HTTPField.Name` does not predefine.
///
/// `HTTPField.Name.init(_:)` is failable, so each name is parsed once here rather
/// than force-unwrapped at every call site (S50).
public enum HTTPHeaderName {
  /// AWS API Gateway echoes its server-generated request id on every response.
  public static let amznRequestId = HTTPField.Name("x-amzn-requestid")

  /// Client-generated id that ties one request to its log entries.
  public static let correlationId = HTTPField.Name("X-Correlation-ID")
}

public extension HTTPFields {
  /// Accesses a header whose name may have failed to parse.
  ///
  /// A name that does not parse can never key a field, so reading through an
  /// unparseable name yields the same result as an absent header and writing
  /// through one is a no-op.
  subscript(optional name: HTTPField.Name?) -> String? {
    get { name.flatMap { self[$0] } }
    set {
      guard let name else { return }
      self[name] = newValue
    }
  }
}
