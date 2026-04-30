// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "OMDFeatures",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "RootFeature", targets: ["RootFeature"]),
    .library(name: "SharedModels", targets: ["SharedModels"]),
    .library(name: "DesignSystem", targets: ["DesignSystem"]),
    .library(name: "LiveActivityClient", targets: ["LiveActivityClient"]),
    .library(name: "FileCellFeature", targets: ["FileCellFeature"]),
    .library(name: "FileDetailFeature", targets: ["FileDetailFeature"]),
    .library(name: "FileListFeature", targets: ["FileListFeature"]),
    .library(name: "LoginFeature", targets: ["LoginFeature"]),
    .library(name: "MainFeature", targets: ["MainFeature"]),
    .library(name: "ActiveDownloadsFeature", targets: ["ActiveDownloadsFeature"]),
    .library(name: "DiagnosticFeature", targets: ["DiagnosticFeature"]),
    .library(name: "DefaultFilesFeature", targets: ["DefaultFilesFeature"]),
    .library(name: "DownloadTrackingFeature", targets: ["DownloadTrackingFeature"]),
    .library(name: "DownloadBehavior", targets: ["DownloadBehavior"]),
    .library(name: "DownloadClient", targets: ["DownloadClient"]),
    .library(name: "ServerClient", targets: ["ServerClient"]),
    .library(name: "ThumbnailCacheClient", targets: ["ThumbnailCacheClient"]),
    .library(name: "APIClient", targets: ["APIClient"]),
    .library(name: "KeychainClient", targets: ["KeychainClient"]),
    .library(name: "AuthenticationClient", targets: ["AuthenticationClient"]),
    .library(name: "PersistenceClient", targets: ["PersistenceClient"]),
    .library(name: "LoggerClient", targets: ["LoggerClient"]),
    .library(name: "FileClient", targets: ["FileClient"]),
    .library(name: "PasteboardClient", targets: ["PasteboardClient"]),
    .library(name: "NotificationRegistrationClient", targets: ["NotificationRegistrationClient"]),
    .library(name: "AnalyticsClient", targets: ["AnalyticsClient"]),
    .library(name: "CorrelationClient", targets: ["CorrelationClient"]),
    .library(name: "PerformanceClient", targets: ["PerformanceClient"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.22.2"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/Square/Valet", from: "4.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
    .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
    .package(path: "../../APITypes"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.9.0"),
  ],
  targets: [
    // ─── Core ─────────────────────────────────────────────────────────

    .target(name: "SharedModels", dependencies: [
      .product(name: "CustomDump", package: "swift-custom-dump"),
    ]),

    .target(name: "DesignSystem", dependencies: [
      "SharedModels",
    ]),

    // ─── Standalone Dependency Clients ─────────────────────────────────

    .target(name: "LoggerClient", dependencies: [
      .product(name: "Dependencies", package: "swift-dependencies"),
      .product(name: "DependenciesMacros", package: "swift-dependencies"),
      .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
    ]),

    .target(name: "AnalyticsClient", dependencies: [
      .product(name: "Dependencies", package: "swift-dependencies"),
      .product(name: "DependenciesMacros", package: "swift-dependencies"),
      .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
    ]),

    .target(name: "CorrelationClient", dependencies: [
      .product(name: "Dependencies", package: "swift-dependencies"),
      .product(name: "DependenciesMacros", package: "swift-dependencies"),
      .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
    ]),

    .target(name: "PerformanceClient", dependencies: [
      .product(name: "Dependencies", package: "swift-dependencies"),
      .product(name: "DependenciesMacros", package: "swift-dependencies"),
      .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
    ]),

    .target(name: "FileClient", dependencies: [
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "ThumbnailCacheClient", dependencies: [
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "PasteboardClient", dependencies: [
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "NotificationRegistrationClient", dependencies: [
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "AuthenticationClient", dependencies: [
      "SharedModels",
      "KeychainClient",
      "LoggerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "KeychainClient", dependencies: [
      "SharedModels",
      "LoggerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      .product(name: "Valet", package: "Valet"),
    ]),

    // ─── API & Networking ──────────────────────────────────────────────

    .target(name: "APIClient", dependencies: [
      "SharedModels",
      .product(name: "APITypes", package: "APITypes"),
      .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
      .product(name: "HTTPTypes", package: "swift-http-types"),
    ]),

    .target(name: "ServerClient", dependencies: [
      "SharedModels",
      "APIClient",
      "LoggerClient",
      "KeychainClient",
      "CorrelationClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      .product(name: "APITypes", package: "APITypes"),
      .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
      .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
      .product(name: "HTTPTypes", package: "swift-http-types"),
    ]),

    // ─── Data Clients ──────────────────────────────────────────────────

    .target(name: "PersistenceClient", dependencies: [
      "SharedModels",
      "APIClient",
      "LoggerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "DownloadClient", dependencies: [
      "LoggerClient",
      "ServerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "LiveActivityClient", dependencies: [
      "SharedModels",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    // ─── Shared Feature Utilities ──────────────────────────────────────

    .target(name: "DownloadBehavior", dependencies: [
      "SharedModels",
      "FileClient",
      "DownloadClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    // ─── Leaf Features ─────────────────────────────────────────────────

    .target(name: "FileCellFeature", dependencies: [
      "SharedModels", "DesignSystem", "DownloadBehavior",
      "ServerClient", "PersistenceClient", "FileClient",
      "DownloadClient", "ThumbnailCacheClient", "LoggerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "FileDetailFeature", dependencies: [
      "SharedModels", "DesignSystem", "DownloadBehavior",
      "PersistenceClient", "FileClient", "DownloadClient",
      "ThumbnailCacheClient", "LoggerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "DefaultFilesFeature", dependencies: [
      "SharedModels", "DesignSystem",
      "DownloadClient", "FileClient", "ServerClient", "PersistenceClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "LoginFeature", dependencies: [
      "SharedModels", "DesignSystem",
      "ServerClient", "KeychainClient", "LoggerClient",
      "AuthenticationClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "ActiveDownloadsFeature", dependencies: [
      "SharedModels", "DesignSystem",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "DownloadTrackingFeature", dependencies: [
      "SharedModels",
      "DownloadClient", "LiveActivityClient", "PersistenceClient", "LoggerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "DiagnosticFeature", dependencies: [
      "SharedModels", "DesignSystem",
      "KeychainClient", "PersistenceClient", "ServerClient", "LoggerClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    // ─── Composite Features ────────────────────────────────────────────

    .target(name: "FileListFeature", dependencies: [
      "SharedModels", "DesignSystem",
      "FileCellFeature", "FileDetailFeature", "DefaultFilesFeature",
      "ServerClient", "PersistenceClient", "LoggerClient",
      "LiveActivityClient", "PasteboardClient", "ThumbnailCacheClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "MainFeature", dependencies: [
      "SharedModels", "DesignSystem",
      "FileListFeature", "LoginFeature", "ActiveDownloadsFeature", "DiagnosticFeature",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    .target(name: "RootFeature", dependencies: [
      "SharedModels", "DesignSystem",
      "LoginFeature", "MainFeature", "DownloadTrackingFeature", "DiagnosticFeature",
      "AuthenticationClient", "ServerClient", "KeychainClient",
      "PersistenceClient", "DownloadClient", "FileClient",
      "LoggerClient", "NotificationRegistrationClient", "LiveActivityClient",
      "ThumbnailCacheClient",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),

    // ─── Tests ─────────────────────────────────────────────────────────

    .target(name: "TestData", dependencies: ["SharedModels", "APIClient"], path: "Tests/TestData"),

    .testTarget(name: "SharedModelsTests", dependencies: ["SharedModels", "TestData"]),
    .testTarget(name: "FileCellFeatureTests", dependencies: [
      "FileCellFeature", "TestData",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),
    .testTarget(name: "FileListFeatureTests", dependencies: [
      "FileListFeature", "TestData",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),
    .testTarget(name: "FileDetailFeatureTests", dependencies: [
      "FileDetailFeature", "TestData",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),
    .testTarget(name: "LoginFeatureTests", dependencies: [
      "LoginFeature", "TestData",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),
    .testTarget(name: "RootFeatureTests", dependencies: [
      "RootFeature", "TestData",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),
    .testTarget(name: "DiagnosticFeatureTests", dependencies: [
      "DiagnosticFeature", "TestData",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),
    .testTarget(name: "DownloadTrackingFeatureTests", dependencies: [
      "DownloadTrackingFeature", "TestData",
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
    ]),
  ]
)
