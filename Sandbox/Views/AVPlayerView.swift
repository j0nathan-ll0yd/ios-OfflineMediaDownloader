//
//  PlayerViewController.swift
//  WWDCPlayer
//
//  Created by Giftbot on 2019/09/13.
//  Copyright © 2019 Giftbot. All rights reserved.
//

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

/*
struct AVPlayerView: UIViewControllerRepresentable {
    let url: URL?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        debugPrint("makeUIViewController")
        
        //let url = URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!
        let player = AVPlayer()
        
        let viewController = AVPlayerViewController()
        viewController.player = player
        viewController.delegate = context.coordinator

        let item = AVPlayerItem(url: url!)

        context.coordinator.observation = item.observe(\.status) { item, change in
            switch item.status {
            case .readyToPlay:
                debugPrint(".readyToPlay")
            case .failed:
                debugPrint(".failed")
            case .unknown:
                debugPrint(".unknown")
            @unknown default:
                fatalError()
            }
        }
        player.replaceCurrentItem(with: item)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: UIViewControllerRepresentableContext<AVPlayerView>) {
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: AVPlayerView.Coordinator) {
        debugPrint("dismantleUIViewController")
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var parent: AVPlayerView
        var observation: NSKeyValueObservation?

        init(_ viewController: AVPlayerView) {
            self.parent = viewController
        }
        
        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            debugPrint("willBeginFullScreenPresentationWithAnimationCoordinator")
        }
        
        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            debugPrint("willEndFullScreenPresentationWithAnimationCoordinator")
        }
        
        
        
    }
}
*/
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
        
        let url = URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!
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
