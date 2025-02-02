//
//  ViewController.swift
//  video
//
//  Created by Alexey Voronov on 21/08/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit


class ViewController: UIViewController {
    
    let queue = OperationQueue()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        queue.maxConcurrentOperationCount = 1
        
        let photoToVideoOp = PhotoToVideoOperation()
        photoToVideoOp.photo = #imageLiteral(resourceName: "test")
        photoToVideoOp.durationInSeconds = 100
        photoToVideoOp.targetSize = photoToVideoOp.photo?.size
        
        var setAudioToVideoOp: SetAudioToVideoOperation?
        
        queue.addOperation(photoToVideoOp)
        
        queue.addOperation {
            guard let url = photoToVideoOp.outputUrl, let audioUrl = Bundle.main.url(forResource: "test", withExtension: "mp3") else { assert(false); return }
            
            setAudioToVideoOp = SetAudioToVideoOperation(audio: AVAsset(url: audioUrl), sourceVideo: AVAsset(url: url))
            setAudioToVideoOp?.start()
        }
        
        queue.addOperation {
            guard let videoWithAudioUrl = setAudioToVideoOp?.outputURL, let justVideoUrl = photoToVideoOp.outputUrl else { assert(false); return }
            
            let saveVideoWithAudioOp = SaveVideoToPhotoLibraryOperation(videoUrl: videoWithAudioUrl)
            saveVideoWithAudioOp.start()
            
            let saveJustVideoOp = SaveVideoToPhotoLibraryOperation(videoUrl: justVideoUrl)
            saveJustVideoOp.start()
        }
        
        queue.addOperation {
            guard let url = setAudioToVideoOp?.outputURL else { assert(false); return }
            DispatchQueue.main.async { AVPlayerViewController.presentAndPlay(mediaAt: url, from: self) }
        }
    }
}

// MARK: -

extension AVPlayerViewController {
    
    class func presentAndPlay(mediaAt url: URL, from presenter: UIViewController) {
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: url)
        presenter.present(vc, animated: true) { vc.player?.play() }
    }
}
