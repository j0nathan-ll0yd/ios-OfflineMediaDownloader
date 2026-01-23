import SwiftUI
import ComposableArchitecture

// MARK: - Lifegames Pro Preview Catalog

/// Preview catalog for Lifegames Pro design system
/// Open this file and use Xcode Previews to view all screens
struct RedesignPreviewCatalog: View {
    @State private var selectedScreen: ScreenType = .launch

    enum ScreenType: String, CaseIterable, Identifiable {
        case launch = "Launch"
        case login = "Login"
        case defaultFiles = "Default"
        case fileList = "Files"
        case fileDetail = "Detail"
        case account = "Account"

        var id: String { rawValue }
    }

    private let theme = DarkProfessionalTheme()

    var body: some View {
        ZStack(alignment: .top) {
            // Consistent background
            theme.backgroundColor
                .ignoresSafeArea()

            // Selected view (full screen, underneath picker)
            selectedView
                .padding(.top, 60) // Make room for picker

            // Screen picker (pinned to top)
            VStack(spacing: 0) {
                Picker("Screen", selection: $selectedScreen) {
                    ForEach(ScreenType.allCases) { screen in
                        Text(screen.rawValue)
                            .tag(screen)
                            .accessibilityIdentifier(screen.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ScreenPicker")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.backgroundColor)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedScreen {
        case .launch:
            LifegamesLaunchView()
        case .login:
            LifegamesLoginView()
        case .defaultFiles:
            LifegamesDefaultFilesView()
        case .fileList:
            LifegamesFileListView()
        case .fileDetail:
            FileDetailPreview()
        case .account:
            LifegamesAccountView()
        }
    }
}

// MARK: - File Detail Preview (Issue #151)

/// Preview of file detail view with rich metadata
struct FileDetailPreview: View {
    var body: some View {
        FileDetailView(store: Store(
            initialState: FileDetailFeature.State(
                file: File(
                    fileId: "preview-1",
                    key: "WWDC 2025 Keynote.mp4",
                    publishDate: Date(),
                    size: 1024 * 1024 * 250,
                    url: URL(string: "https://example.com/video.mp4"),
                    title: "WWDC 2025 Keynote",
                    description: "Apple's annual developer conference keynote presentation featuring the latest innovations in iOS, macOS, and more.",
                    authorName: "Apple",
                    duration: 7200,  // 2 hours
                    uploadDate: "20250609",
                    viewCount: 1_500_000,
                    thumbnailUrl: "https://example.com/thumbnail.jpg"
                ),
                isDownloaded: true
            )
        ) {
            FileDetailFeature()
        })
    }
}

// MARK: - Previews

#Preview("Design Catalog") {
    RedesignPreviewCatalog()
}

#Preview("All Screens") {
    TabView {
        LifegamesLaunchView().tabItem { Text("Launch") }
        LifegamesLoginView().tabItem { Text("Login") }
        LifegamesDefaultFilesView().tabItem { Text("Default") }
        LifegamesFileListView().tabItem { Text("Files") }
        LifegamesAccountView().tabItem { Text("Account") }
    }
    .preferredColorScheme(.dark)
}

#Preview("Login - Not Registered") {
    LifegamesLoginView(registeredUserName: nil)
}

#Preview("Login - Registered") {
    LifegamesLoginView(registeredUserName: "Jonathan Lloyd")
}
