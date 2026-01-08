import SwiftUI

// MARK: - Lifegames Pro Preview Catalog

/// Preview catalog for Lifegames Pro design system
/// Open this file and use Xcode Previews to view all screens
struct RedesignPreviewCatalog: View {
    @State private var selectedScreen: ScreenType = .launch

    enum ScreenType: String, CaseIterable, Identifiable {
        case launch = "Launch"
        case login = "Login"
        case defaultFiles = "Default Files"
        case fileList = "Files"
        case account = "Account"

        var id: String { rawValue }
    }

    var body: some View {
        ZStack(alignment: .top) {
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
                .background(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
        case .account:
            LifegamesAccountView()
        }
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
