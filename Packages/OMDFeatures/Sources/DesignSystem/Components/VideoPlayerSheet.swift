import SwiftUI
import AVKit
import AVFoundation

/// Wrapper view that adds swipe-to-dismiss and loading state to the video player
public struct VideoPlayerSheet: View {
  let url: URL
  let onDismiss: () -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var isLoading = true

  public init(url: URL, onDismiss: @escaping () -> Void) {
    self.url = url
    self.onDismiss = onDismiss
  }

  public var body: some View {
    ZStack {
      MediaPlayerView(url: url, isLoading: $isLoading)
        .ignoresSafeArea()

      // Loading overlay
      if isLoading {
        ZStack {
          Color.black
          ProgressView()
            .scaleEffect(1.5)
            .tint(.white)
        }
        .ignoresSafeArea()
      }
    }
    .background(Color.black)
    .offset(y: dragOffset)
    .gesture(
      DragGesture()
        .onChanged { value in
          // Only allow downward drag
          if value.translation.height > 0 {
            dragOffset = value.translation.height
          }
        }
        .onEnded { value in
          if value.translation.height > 150 {
            onDismiss()
          } else {
            withAnimation(.spring(response: 0.3)) {
              dragOffset = 0
            }
          }
        }
    )
  }
}

/// Native iOS video player using AVPlayerViewController
/// Provides full-featured playback with native controls, PiP support, and better performance
public struct MediaPlayerView: UIViewControllerRepresentable {
  let url: URL
  @Binding var isLoading: Bool

  /// Minimum file size threshold to consider a file valid (100 KB)
  /// Files smaller than this are likely corrupted or incomplete downloads
  private static let minimumValidFileSize: Int64 = 100_000

  public init(url: URL, isLoading: Binding<Bool>) {
    self.url = url
    self._isLoading = isLoading
  }

  public func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()

    // Setup audio session for playback
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      // Audio session setup failed — playback may still work without explicit session config
    }

    // File validation
    guard FileManager.default.fileExists(atPath: url.path) else {
      context.coordinator.showError("File not found", in: controller)
      Task { @MainActor in self.isLoading = false }
      return controller
    }

    // Quick size check for corrupted files
    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
       let size = attrs[.size] as? Int64, size < Self.minimumValidFileSize {
      context.coordinator.showError("File corrupted (\(size) bytes).\nDelete and re-download.", in: controller)
      Task { @MainActor in self.isLoading = false }
      return controller
    }

    // Create player - DON'T play yet, wait for ready state
    let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let playerItem = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: playerItem)

    // Configure player settings
    player.automaticallyWaitsToMinimizeStalling = true

    // Configure player view controller
    controller.player = player
    controller.allowsPictureInPicturePlayback = true
    controller.canStartPictureInPictureAutomaticallyFromInline = true
    controller.delegate = context.coordinator

    // Wait for player item to be ready, then play and hide loader
    context.coordinator.waitForReadyThenPlay(playerItem: playerItem, player: player) { @Sendable in
      Task { @MainActor in self.isLoading = false }
    }

    return controller
  }

  public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    // No updates needed
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  @MainActor
  public class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    private var statusObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?

    nonisolated public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {}

    nonisolated public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {}

    public func waitForReadyThenPlay(playerItem: AVPlayerItem, player: AVPlayer, onReady: @escaping @Sendable () -> Void) {
      statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
        Task { @MainActor [weak self] in
          guard let self else { return }

          switch item.status {
          case .readyToPlay:
            if item.isPlaybackLikelyToKeepUp {
              self.startPlayback(player: player, onReady: onReady)
            } else {
              self.waitForBuffer(playerItem: item, player: player, onReady: onReady)
            }
          case .failed:
            onReady()
          case .unknown:
            break
          @unknown default:
            break
          }
        }
      }
    }

    private func waitForBuffer(playerItem: AVPlayerItem, player: AVPlayer, onReady: @escaping @Sendable () -> Void) {
      bufferObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
        if item.isPlaybackLikelyToKeepUp {
          Task { @MainActor [weak self] in
            self?.startPlayback(player: player, onReady: onReady)
          }
        }
      }
    }

    private func startPlayback(player: AVPlayer, onReady: @escaping @Sendable () -> Void) {
      // Clean up observers
      statusObservation?.invalidate()
      statusObservation = nil
      bufferObservation?.invalidate()
      bufferObservation = nil

      // Already on MainActor — play directly
      player.play()
      onReady()
    }

    public func showError(_ message: String, in controller: AVPlayerViewController) {
      let errorLabel = UILabel()
      errorLabel.text = message
      errorLabel.textColor = .white
      errorLabel.textAlignment = .center
      errorLabel.numberOfLines = 0
      errorLabel.translatesAutoresizingMaskIntoConstraints = false

      controller.view.addSubview(errorLabel)
      NSLayoutConstraint.activate([
        errorLabel.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
        errorLabel.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
        errorLabel.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 20),
        errorLabel.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -20)
      ])
    }

    deinit {
      statusObservation?.invalidate()
      bufferObservation?.invalidate()
    }
  }
}
