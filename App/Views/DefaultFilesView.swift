import SwiftUI
import ComposableArchitecture
import AVKit

// MARK: - Sample File Data

struct SampleFile {
  static let url = URL(string: "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4")!
  static let title = "Big Buck Bunny (Sample)"
  static let description = "A public domain animated short film - perfect for testing downloads."
  static let size: Int64 = 1_048_576  // ~1 MB
}

// MARK: - DefaultFilesFeature

@Reducer
struct DefaultFilesFeature {
  @ObservableState
  struct State: Equatable {
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var isDownloaded: Bool = false
    var showBenefits: Bool = false
    var isPlaying: Bool = false
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action {
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

  private enum CancelID { case download }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .downloadButtonTapped:
        // Check if already downloaded
        if fileClient.fileExists(SampleFile.url) {
          state.isDownloaded = true
          return .none
        }

        state.isDownloading = true
        state.downloadProgress = 0
        return .run { send in
          let stream = downloadClient.downloadFile(SampleFile.url, SampleFile.size)
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
        state.isPlaying = true
        return .none

      case let .setPlaying(isPlaying):
        state.isPlaying = isPlaying
        return .none

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
    .alert($store.scope(state: \.alert, action: \.alert))
    .fullScreenCover(isPresented: $store.isPlaying.sending(\.setPlaying)) {
      videoPlayerContent
    }
    .task {
      // Check if already downloaded on appear
      if fileClient.fileExists(SampleFile.url) {
        store.send(.downloadCompleted(fileClient.filePath(SampleFile.url)))
      }
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
      } else if !store.isDownloading {
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

          if store.isDownloading {
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
          Text(SampleFile.title)
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
            Text(formatSize(SampleFile.size))
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
    .disabled(store.isDownloading)
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
    let localURL = fileClient.filePath(SampleFile.url)
    VideoPlayerSheet(url: localURL) {
      store.send(.setPlaying(false))
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
