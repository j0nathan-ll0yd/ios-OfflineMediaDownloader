/// App-local presentational download state for OMD media components.
///
/// Replaces the gallery fixture download state; the real app maps its domain
/// status onto this enum at the call site.
public enum OMDDownloadState: Equatable, Sendable {
  case none
  case queued
  case downloaded
  case downloading(progress: Double)
}
