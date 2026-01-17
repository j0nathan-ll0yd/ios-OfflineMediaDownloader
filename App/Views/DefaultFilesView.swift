import SwiftUI
import ComposableArchitecture
import AVKit

// MARK: - DefaultFilesFeature

@Reducer
struct DefaultFilesFeature {
  @ObservableState
  struct State: Equatable {
    var isLoadingFile: Bool = true
    var file: File?
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var isDownloaded: Bool = false
    var showBenefits: Bool = false
    var isPlaying: Bool = false
    /// Shows loading overlay immediately when play is tapped
    var isPreparingToPlay: Bool = false
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action {
    case onAppear
    case fileLoaded(File?)
    case fileFetchFailed(String)
    /// Called by parent when it has already fetched files - avoids duplicate API call
    case parentProvidedFile(File?)
    case downloadButtonTapped
    case playButtonTapped
    case downloadProgress(Int)
    case downloadCompleted(URL)
    case downloadFailed(String)
    case registerButtonTapped
    case toggleBenefits
    case setPlaying(Bool)
    case alert(PresentationAction<Alert>)

    @CasePathable
    enum Alert: Equatable {
      case dismiss
    }
  }

  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.coreDataClient) var coreDataClient

  private enum CancelID { case download }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        // Don't fetch here - parent (FileListFeature) will provide the file
        // via parentProvidedFile action to avoid duplicate API calls.
        // Just mark as loading until parent provides data.
        guard state.file == nil else { return .none }
        state.isLoadingFile = true
        return .none

      case let .parentProvidedFile(file):
        // Parent has fetched files and is sharing with us
        state.isLoadingFile = false
        state.file = file
        // Check if already downloaded
        if let url = file?.url, fileClient.fileExists(url) {
          state.isDownloaded = true
        }
        return .none

      case let .fileLoaded(file):
        state.isLoadingFile = false
        state.file = file
        // Check if already downloaded
        if let url = file?.url, fileClient.fileExists(url) {
          state.isDownloaded = true
        }
        return .none

      case let .fileFetchFailed(message):
        state.isLoadingFile = false
        state.alert = AlertState {
          TextState("Failed to Load")
        } actions: {
          ButtonState(action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState(message)
        }
        return .none

      case .downloadButtonTapped:
        guard let file = state.file, let url = file.url else { return .none }

        // Check if already downloaded
        if fileClient.fileExists(url) {
          state.isDownloaded = true
          return .none
        }

        state.isDownloading = true
        state.downloadProgress = 0
        let fileSize = Int64(file.size ?? 0)
        return .run { send in
          let stream = downloadClient.downloadFile(url, fileSize)
          for await progress in stream {
            switch progress {
            case let .progress(percent):
              await send(.downloadProgress(percent))
            case let .completed(localURL):
              await send(.downloadCompleted(localURL))
            case let .failed(message):
              await send(.downloadFailed(message))
            }
          }
        }
        .cancellable(id: CancelID.download)

      case let .downloadProgress(percent):
        state.downloadProgress = Double(percent) / 100.0
        return .none

      case .downloadCompleted:
        state.isDownloading = false
        state.isDownloaded = true
        return .none

      case let .downloadFailed(message):
        state.isDownloading = false
        state.alert = AlertState {
          TextState("Download Failed")
        } actions: {
          ButtonState(action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState(message)
        }
        return .none

      case .playButtonTapped:
        state.isPreparingToPlay = true
        // Delay showing fullScreenCover slightly so loading overlay renders first
        return .run { send in
          try? await Task.sleep(for: .milliseconds(50))
          await send(.setPlaying(true))
        }

      case let .setPlaying(isPlaying):
        state.isPlaying = isPlaying
        if !isPlaying {
          state.isPreparingToPlay = false
          return .none
        }
        // Increment play count when starting playback
        return .run { [coreDataClient] _ in
          try? await coreDataClient.incrementPlayCount()
        }

      case .registerButtonTapped:
        // Handled by parent
        return .none

      case .toggleBenefits:
        state.showBenefits.toggle()
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - DefaultFilesView

struct DefaultFilesView: View {
  @Bindable var store: StoreOf<DefaultFilesFeature>
  let onRegisterTapped: () -> Void

  @Dependency(\.fileClient) var fileClient

  private let theme = DarkProfessionalTheme()

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        iconHeader
        sampleSection
          .padding(.top, 20)

        Spacer(minLength: 60)

        bottomCTA
          .padding(.horizontal, 16)
          .padding(.bottom, 32)
      }
    }
    .background(theme.backgroundColor)
    .overlay {
      // Loading overlay shown immediately when play is tapped
      if store.isPreparingToPlay {
        ZStack {
          Color.black.opacity(0.8)
            .ignoresSafeArea()
          ProgressView()
            .scaleEffect(1.5)
            .tint(.white)
        }
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .fullScreenCover(isPresented: $store.isPlaying.sending(\.setPlaying)) {
      videoPlayerContent
    }
    .task {
      store.send(.onAppear)
    }
  }

  // MARK: - Icon Header

  private var iconHeader: some View {
    HStack(spacing: 12) {
      Image(systemName: "sparkles")
        .font(.title3)
        .foregroundStyle(theme.primaryColor)
      Text("Try the sample file below to see how downloading works.")
        .font(.subheadline)
        .foregroundStyle(theme.textSecondary)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.primaryColor.opacity(0.1))
  }

  // MARK: - Sample Section

  private var sampleSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("SAMPLE")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 20)

      sampleFileRow
        .padding(.horizontal, 16)
    }
  }

  private var sampleFileRow: some View {
    Button {
      if store.isDownloaded {
        store.send(.playButtonTapped)
      } else if !store.isDownloading && !store.isLoadingFile {
        store.send(.downloadButtonTapped)
      }
    } label: {
      HStack(spacing: 12) {
        // Thumbnail
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(
              LinearGradient(
                colors: [theme.primaryColor, theme.accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 60, height: 60)

          if store.isLoadingFile {
            ProgressView()
              .tint(.white)
          } else if store.isDownloading {
            circularProgressView
          } else if store.isDownloaded {
            Image(systemName: "play.fill")
              .foregroundStyle(.white)
          } else {
            Image(systemName: "arrow.down")
              .foregroundStyle(.white)
          }
        }

        // File info
        VStack(alignment: .leading, spacing: 4) {
          if store.isLoadingFile {
            Text("Loading...")
              .font(.body)
              .fontWeight(.medium)
              .foregroundStyle(.white)

            Text("Fetching file info")
              .font(.caption)
              .foregroundStyle(theme.textSecondary)
          } else if let file = store.file {
            Text(file.title ?? file.key)
              .font(.body)
              .fontWeight(.medium)
              .foregroundStyle(.white)

            if store.isDownloading {
              Text("Downloading \(Int(store.downloadProgress * 100))%")
                .font(.caption)
                .foregroundStyle(theme.primaryColor)
                .monospacedDigit()
            } else if store.isDownloaded {
              Text("Ready to play")
                .font(.caption)
                .foregroundStyle(theme.successColor)
            } else {
              Text(formatSize(Int64(file.size ?? 0)))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            }
          } else {
            Text("No files available")
              .font(.body)
              .fontWeight(.medium)
              .foregroundStyle(.white)

            Text("Check back later")
              .font(.caption)
              .foregroundStyle(theme.textSecondary)
          }
        }

        Spacer()

        // Progress ring (when downloading)
        if store.isDownloading {
          glowingProgressRing
        }
      }
      .padding(12)
      .background(DarkProfessionalTheme.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .disabled(store.isDownloading || store.isLoadingFile || store.file == nil)
  }

  private var circularProgressView: some View {
    ZStack {
      Circle()
        .stroke(Color.white.opacity(0.3), lineWidth: 3)

      Circle()
        .trim(from: 0, to: store.downloadProgress)
        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90))

      Text("\(Int(store.downloadProgress * 100))%")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .monospacedDigit()
    }
    .frame(width: 32, height: 32)
  }

  private var glowingProgressRing: some View {
    ZStack {
      Circle()
        .fill(theme.primaryColor.opacity(0.2))
        .frame(width: 44, height: 44)
        .blur(radius: 8)

      Circle()
        .stroke(theme.primaryColor.opacity(0.2), lineWidth: 3)
        .frame(width: 36, height: 36)

      Circle()
        .trim(from: 0, to: store.downloadProgress)
        .stroke(
          LinearGradient(
            colors: [theme.primaryColor, theme.accentColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .frame(width: 36, height: 36)
        .rotationEffect(.degrees(-90))

      Text("\(Int(store.downloadProgress * 100))")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .monospacedDigit()
    }
  }

  // MARK: - Bottom CTA

  private var bottomCTA: some View {
    VStack(spacing: 16) {
      Text("Want your own videos?")
        .font(.subheadline)
        .foregroundStyle(.white)

      Button(action: onRegisterTapped) {
        Text("Create Free Account")
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .padding(.horizontal, 32)
          .padding(.vertical, 14)
          .background(
            LinearGradient(
              colors: [theme.primaryColor, theme.accentColor],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .clipShape(Capsule())
      }

      Button {
        store.send(.toggleBenefits, animation: .spring(response: 0.3))
      } label: {
        HStack(spacing: 4) {
          Text("Why create an account?")
          Image(systemName: store.showBenefits ? "chevron.up" : "chevron.down")
            .font(.caption2)
        }
        .font(.caption)
        .foregroundStyle(theme.textSecondary)
      }

      if store.showBenefits {
        VStack(alignment: .leading, spacing: 8) {
          benefitRow(icon: "icloud.and.arrow.down", text: "Download videos from your personal library")
          benefitRow(icon: "arrow.triangle.2.circlepath", text: "Sync across all your devices")
          benefitRow(icon: "bell.badge", text: "Get notified when new content is available")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DarkProfessionalTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
        )
      }
    }
  }

  private func benefitRow(icon: String, text: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.caption)
        .foregroundStyle(theme.primaryColor)
        .frame(width: 20)
      Text(text)
        .font(.caption)
        .foregroundStyle(theme.textSecondary)
    }
  }

  // MARK: - Video Player

  @ViewBuilder
  private var videoPlayerContent: some View {
    if let file = store.file, let url = file.url {
      let localURL = fileClient.filePath(url)
      VideoPlayerSheet(url: localURL) {
        store.send(.setPlaying(false))
      }
    }
  }

  // MARK: - Helpers

  private func formatSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}

#Preview {
  NavigationStack {
    DefaultFilesView(
      store: Store(initialState: DefaultFilesFeature.State()) {
        DefaultFilesFeature()
      },
      onRegisterTapped: {}
    )
    .navigationTitle("Files")
    .navigationBarTitleDisplayMode(.large)
    .toolbarColorScheme(.dark, for: .navigationBar)
  }
  .preferredColorScheme(.dark)
}
