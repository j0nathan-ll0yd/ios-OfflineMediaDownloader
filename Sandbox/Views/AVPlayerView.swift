import AVKit
import SwiftUI

struct AVPlayerView: UIViewControllerRepresentable {
    var url: URL?
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<AVPlayerView>) -> AVPlayerViewController {
        debugPrint("makeUIViewController")
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
        debugPrint("viewWillDisappear")
        self.player!.pause()
    }
    override func viewDidDisappear(_ animated: Bool) {
        debugPrint("viewDidDisappear")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        debugPrint("viewWillAppear has appeared")
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder : Bool {
        return true
    }
    
    override func remoteControlReceived(with event: UIEvent?) {
        debugPrint("in remoteControlReceivedWithEvent")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        debugPrint("shouldWaitForLoadingOfRequestedResource")
        debugPrint(loadingRequest)
        return false
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        debugPrint("didCancel")
        debugPrint(loadingRequest)
    }
    
}
