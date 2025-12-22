import SwiftUI
import AVKit
import AVFoundation

/// Native iOS video player using AVPlayerViewController
/// Provides full-featured playback with native controls, PiP support, and better performance
struct MediaPlayerView: UIViewControllerRepresentable {
  let url: URL
  let onDismiss: () -> Void
  
  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    
    // Setup audio session for playback
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("🎬 MediaPlayerView: Audio session error: \(error)")
    }
    
    // File validation
    guard FileManager.default.fileExists(atPath: url.path) else {
      print("🎬 MediaPlayerView: File not found: \(url.path)")
      // Show error in the player
      context.coordinator.showError("File not found", in: controller)
      return controller
    }
    
    // Quick size check for corrupted files
    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
       let size = attrs[.size] as? Int64, size < 100_000 {
      print("🎬 MediaPlayerView: File corrupted (\(size) bytes)")
      context.coordinator.showError("File corrupted (\(size) bytes).\nDelete and re-download.", in: controller)
      return controller
    }
    
    // Create player
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
    
    // Start playback
    player.play()
    
    print("🎬 MediaPlayerView: Playing: \(url.lastPathComponent)")
    
    return controller
  }
  
  func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    // No updates needed
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }
  
  class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    let onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void) {
      self.onDismiss = onDismiss
    }
    
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
      print("🎬 MediaPlayerView: Starting Picture in Picture")
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
      print("🎬 MediaPlayerView: Stopped Picture in Picture")
    }
    
    func showError(_ message: String, in controller: AVPlayerViewController) {
      // Create a simple error view
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
  }
}
