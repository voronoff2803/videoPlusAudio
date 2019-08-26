//
//  ViewController.swift
//  video
//
//  Created by Alexey Voronov on 21/08/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let queue = OperationQueue()
        let oper = PhotoToVideoOperation(photo: #imageLiteral(resourceName: "test"), durationInSeconds: 800)
        
        oper.completionBlock = {
            if oper.outputURL != nil {
                print(oper.outputURL ?? "")
                let oper2 = SetAudioToVideoOperation(audio: AVAsset(url: Bundle.main.url(forResource: "test", withExtension: "mp3")!), sourceVideo: AVAsset(url: oper.outputURL!))
                oper2.completionBlock = {
                    if oper2.outputURL != nil {
                        print(oper2.outputURL ?? "")
                        //let activity = UIActivityViewController(activityItems: [oper2.outputURL as Any], applicationActivities: nil)
                        DispatchQueue.main.async {
                        //    self.present(activity, animated: true)
                        }
                    } else {
                        print(oper2.outputError ?? "")
                    }
                }
                
                queue.addOperation(oper2)
            } else {
                print(oper.outputError ?? "")
            }
        }
        
        queue.addOperation(oper)
        
    }
}

