//
//  SetAudioToVideoOperation.swift
//  video
//
//  Created by Alexey Voronov on 21/08/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import Foundation
import AVFoundation

class SetAudioToVideoOperation: Operation {
    let audio: AVAsset
    let sourceVideo: AVAsset
    
    var outputURL: URL?
    var outputError: Error?

    init(audio: AVAsset, sourceVideo: AVAsset) {
        self.audio = audio
        self.sourceVideo = sourceVideo
    }
    
    func addAudioToComposition(compositionTrackAudio: AVMutableCompositionTrack, audioTrack: AVAssetTrack, videoDuration: CMTime) {
        while compositionTrackAudio.timeRange.duration < videoDuration || compositionTrackAudio.timeRange.duration == .invalid {
            var insertionAudioTime = CMTime.zero
            if compositionTrackAudio.timeRange.duration.isValid {
                insertionAudioTime = compositionTrackAudio.timeRange.duration
            }
            do {
                if videoDuration - insertionAudioTime < audioTrack.timeRange.duration {
                    try compositionTrackAudio.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: videoDuration - insertionAudioTime), of: audioTrack, at: insertionAudioTime)
                } else {
                    try compositionTrackAudio.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: audioTrack.timeRange.duration), of: audioTrack, at: insertionAudioTime)
                }
            } catch {
                outputError = error
                return
            }
        }
    }
    
    override func main() {
        let dir = NSTemporaryDirectory() + UUID().uuidString + ".m4v"
        
        let mixComposition = AVMutableComposition()
        var mutableCompositionVideoTrack = [AVMutableCompositionTrack]()
        var mutableCompositionAudioTrack = [AVMutableCompositionTrack]()
        
        
        guard let compositionAddAudio = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid), let compositionAddVideo = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let aVideoAssetTrack = sourceVideo.tracks(withMediaType: AVMediaType.video).first,
            let aAudioAssetTrack = audio.tracks(withMediaType: AVMediaType.audio).first
            else {
                assert(false, "composition audio error")
                return
        }

        compositionAddVideo.preferredTransform = aVideoAssetTrack.preferredTransform
        
        mutableCompositionVideoTrack.append(compositionAddVideo)
        mutableCompositionAudioTrack.append(compositionAddAudio)
        
        do {
            try mutableCompositionVideoTrack[0].insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aVideoAssetTrack, at: CMTime.zero)
        } catch {
            outputError = error
        }
        
        addAudioToComposition(compositionTrackAudio: mutableCompositionAudioTrack[0], audioTrack: aAudioAssetTrack, videoDuration: mutableCompositionVideoTrack[0].timeRange.duration)
    
        guard let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            assert(false, "assetExport failure")
        }
        assetExport.outputFileType = AVFileType.m4v
        assetExport.outputURL = URL(fileURLWithPath: dir)
        assetExport.shouldOptimizeForNetworkUse = true
        
        let semaphore = DispatchSemaphore(value: 0)
        
        assetExport.exportAsynchronously {
            switch assetExport.status {
            case .completed: self.outputURL = assetExport.outputURL
            default: self.outputError = assetExport.error }
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}
