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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let queue = OperationQueue()
        let oper1 = PhotoToVideoOperation(photo: #imageLiteral(resourceName: "test"), durationInSeconds: 800)
        
        oper1.completionBlock = {
            if oper1.outputURL != nil {
                print("video: \(oper1.outputURL!)")
                
                let oper2 = SetAudioToVideoOperation(audio: AVAsset(url: Bundle.main.url(forResource: "test", withExtension: "mp3")!), sourceVideo: AVAsset(url: oper1.outputURL!))
                queue.addOperation(oper2)
                oper2.completionBlock = {
                    if oper2.outputURL != nil {
                        print("video+audio: \(oper2.outputURL!)")
                        
                        self.playVideo(url: oper2.outputURL!)
                    } else {
                        assert(false, oper2.outputError?.localizedDescription ?? "")
                    }
                }
                
            } else {
                assert(false, oper1.outputError?.localizedDescription ?? "")
            }
        }
        queue.addOperation(oper1)
    }
    
    func playVideo(url: URL) {
        DispatchQueue.main.async {
            let player = AVPlayer(url: url)
            
            let vc = AVPlayerViewController()
            vc.player = player
            
            self.present(vc, animated: true) { vc.player?.play() }
        }
    }
}

