import AVKit
import SwiftUI

struct AVPlayerView: UIViewControllerRepresentable {
    var url: URL?
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<AVPlayerView>) -> AVPlayerViewController {
        let controller = PlayerViewController()
        controller.url = url
        return controller
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: UIViewControllerRepresentableContext<AVPlayerView>) {
    }
    
}

class PlayerViewController: AVPlayerViewController, AVAssetResourceLoaderDelegate {
    
    var url: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        debugPrint("viewDidLoad")
        //UIApplication.shared.beginReceivingRemoteControlEvents()
        
        do {
            // Removed deprecated use of AVAudioSessionDelegate protocol
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
        } catch _ {
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch _ {
        }
        
        let asset: AVURLAsset = AVURLAsset(url: self.url!)
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem:playerItem)
        self.player!.playImmediately(atRate: 1.0)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.player!.pause()
    }
    override func viewDidDisappear(_ animated: Bool) {
    }
    
    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder : Bool {
        return true
    }
    
    override func remoteControlReceived(with event: UIEvent?) {
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        return false
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
    }
    
}
