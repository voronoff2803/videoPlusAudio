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
    
    override func main() {
        let composition = AVMutableComposition()
        
        guard
            let videoTrack = sourceVideo.tracks(withMediaType: AVMediaType.video).first,
            let audioTrack = audio.tracks(withMediaType: AVMediaType.audio).first,
            let audioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let videoCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { assert(false); return }
        
        videoCompositionTrack.preferredTransform = videoTrack.preferredTransform
        
        do {
            try videoCompositionTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoTrack.timeRange.duration), of: videoTrack, at: CMTime.zero)
            try addAudioToComposition(compositionTrackAudio: audioCompositionTrack, audioTrack: audioTrack, videoDuration: videoCompositionTrack.timeRange.duration)
            exportSynchronously(composition: composition)
        }
        catch { outputError = error }
    }
    
    func addAudioToComposition(compositionTrackAudio: AVMutableCompositionTrack, audioTrack: AVAssetTrack, videoDuration: CMTime) throws {
        while compositionTrackAudio.timeRange.duration < videoDuration || compositionTrackAudio.timeRange.duration == .invalid {
            let insertionAudioTime = compositionTrackAudio.timeRange.duration.isValid ? compositionTrackAudio.timeRange.duration : .zero
            
            let audioDuration = videoDuration - insertionAudioTime < audioTrack.timeRange.duration ? videoDuration - insertionAudioTime : audioTrack.timeRange.duration
            try compositionTrackAudio.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: audioDuration), of: audioTrack, at: insertionAudioTime)
        }
    }
    
    func exportSynchronously(composition: AVComposition) {
        guard let assetExport = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { assert(false); return }
        
        assetExport.outputFileType = AVFileType.m4v
        assetExport.outputURL = URL(fileURLWithPath: NSTemporaryDirectory() + UUID().uuidString + ".m4v")
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
