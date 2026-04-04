import AVFoundation
import AVKit
import SwiftUI

/// Wrapper view that adds swipe-to-dismiss and loading state to the video player
struct VideoPlayerSheet: View {
  let url: URL
  let onDismiss: () -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var isLoading = true

  var body: some View {
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
struct MediaPlayerView: UIViewControllerRepresentable {
  let url: URL
  @Binding var isLoading: Bool

  /// Minimum file size threshold to consider a file valid (100 KB)
  /// Files smaller than this are likely corrupted or incomplete downloads
  private static let minimumValidFileSize: Int64 = 100_000

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()

    // Setup audio session for playback
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      #if DEBUG
      print("🎬 MediaPlayerView: Audio session error: \(error)")
      #endif
    }

    // File validation
    guard FileManager.default.fileExists(atPath: url.path) else {
      #if DEBUG
      print("🎬 MediaPlayerView: File not found: \(url.path)")
      #endif
      context.coordinator.showError("File not found", in: controller)
      Task { @MainActor in self.isLoading = false }
      return controller
    }

    // Quick size check for corrupted files
    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
       let size = attrs[.size] as? Int64, size < Self.minimumValidFileSize {
      #if DEBUG
      print("🎬 MediaPlayerView: File corrupted (\(size) bytes)")
      #endif
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

    #if DEBUG
    print("🎬 MediaPlayerView: Loading: \(url.lastPathComponent)")
    #endif

    return controller
  }

  func updateUIViewController(_: AVPlayerViewController, context _: Context) {
    // No updates needed
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  @MainActor
  class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    private var statusObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?

    nonisolated func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
      #if DEBUG
      print("🎬 MediaPlayerView: Starting Picture in Picture")
      #endif
    }

    nonisolated func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
      #if DEBUG
      print("🎬 MediaPlayerView: Stopped Picture in Picture")
      #endif
    }

    func waitForReadyThenPlay(playerItem: AVPlayerItem, player: AVPlayer, onReady: @escaping @Sendable () -> Void) {
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
            #if DEBUG
            print("🎬 MediaPlayerView: Failed to load: \(item.error?.localizedDescription ?? "unknown")")
            #endif
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
      #if DEBUG
      print("🎬 MediaPlayerView: Playback started")
      #endif
      onReady()
    }

    func showError(_ message: String, in controller: AVPlayerViewController) {
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
        errorLabel.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -20),
      ])
    }

    deinit {
      statusObservation?.invalidate()
      bufferObservation?.invalidate()
    }
  }
}
