//
//  SaveVideoToPhotoLibraryOperation.swift
//  video
//
//  Created by Bogdan Pashchenko on 9/8/19.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import Foundation
import Photos

class SaveVideoToPhotoLibraryOperation: Operation {
    
    let videoUrl: URL
    init(videoUrl: URL) { self.videoUrl = videoUrl }
    
    override func main() {
        let sema = DispatchSemaphore(value: 0)
        
        PHPhotoLibrary.requestAuthorization { status in
            assert(status == .authorized)
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoUrl)
            }, completionHandler: { saved, error in
                assert(saved && error == nil)
                sema.signal()
            })
        }
        
        sema.wait()
    }
}
