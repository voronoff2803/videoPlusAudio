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
    
    func addAudioToComposition(compositionTrackAudio: AVMutableCompositionTrack, audioTrack: AVAssetTrack, videoDuration: CMTime) throws {
        while compositionTrackAudio.timeRange.duration < videoDuration || compositionTrackAudio.timeRange.duration == .invalid {
            let insertionAudioTime = compositionTrackAudio.timeRange.duration.isValid ? compositionTrackAudio.timeRange.duration : .zero
            
            let audioDuration = videoDuration - insertionAudioTime < audioTrack.timeRange.duration ? videoDuration - insertionAudioTime : audioTrack.timeRange.duration
            try compositionTrackAudio.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: audioDuration), of: audioTrack, at: insertionAudioTime)
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
            else { assert(false); return }
        
        compositionAddVideo.preferredTransform = aVideoAssetTrack.preferredTransform
        mutableCompositionVideoTrack.append(compositionAddVideo)
        mutableCompositionAudioTrack.append(compositionAddAudio)
        
        do {
            try mutableCompositionVideoTrack[0].insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aVideoAssetTrack, at: CMTime.zero)
            try addAudioToComposition(compositionTrackAudio: mutableCompositionAudioTrack[0], audioTrack: aAudioAssetTrack, videoDuration: mutableCompositionVideoTrack[0].timeRange.duration)
        }
        catch { outputError = error }
        
        guard let assetExport = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { assert(false); return }
        
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
