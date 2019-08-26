//
//  PhotoToVideoOperation.swift
//  video
//
//  Created by Alexey Voronov on 21/08/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import AVFoundation
import UIKit

class PhotoToVideoOperation: Operation {
    let photo: UIImage
    let durationInSeconds: Double
    
    var outputURL: URL?
    var outputError: Error?
    
    init(photo: UIImage, durationInSeconds: Double) {
        self.photo = photo
        self.durationInSeconds = durationInSeconds
    }
    
    override func main() {
        let dir = NSTemporaryDirectory() + UUID().uuidString + ".m4v"
        let vidDuration = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
        
        let videoSettings = [
            AVVideoCodecKey  : AVVideoCodecType.h264,
            AVVideoWidthKey  : photo.size.width,
            AVVideoHeightKey : photo.size.height
            ] as [String : AnyObject]
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        
        let sourceBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey: Float(photo.size.width),
            kCVPixelBufferHeightKey:  Float(photo.size.height),
            kCVPixelBufferCGImageCompatibilityKey: NSNumber(value: true),
            kCVPixelBufferCGBitmapContextCompatibilityKey: NSNumber(value: true)
        ] as [String : AnyObject]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        do {
            let videoWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: dir), fileType: .m4v)
            videoWriter.add(videoWriterInput)
            
            if videoWriter.startWriting() {
                videoWriter.startSession(atSourceTime: CMTime.zero)
                
                guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
                    assert(false, "pixelBufferPool failed")
                    return
                }
                
                guard let imagePixelBuffer = pixelBufferFromImage(image: photo, pixelBufferPool: pixelBufferPool, size: photo.size) else {
                    assert(false, "imagePixelBuffer failed")
                    return
                }
                
                assert(videoWriterInput.isReadyForMoreMediaData)
                pixelBufferAdaptor.append(imagePixelBuffer, withPresentationTime: CMTime.zero)
                pixelBufferAdaptor.append(imagePixelBuffer, withPresentationTime: vidDuration)
                
                let semaphore = DispatchSemaphore(value: 0)
                
                videoWriterInput.markAsFinished()
                videoWriter.endSession(atSourceTime: vidDuration)
                videoWriter.finishWriting {
                    defer { semaphore.signal() }
                    guard videoWriter.status == .completed else { self.outputError = videoWriter.error; return }
                    self.outputURL = URL(fileURLWithPath: dir)
                }
                
                semaphore.wait()
            }
        } catch {
            self.outputError = error
        }
    }
    
    func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else {
            assert(false)
            return nil
        }
        
        var pixelBufferOut: CVPixelBuffer?
        
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
        assert(status == kCVReturnSuccess, "CVPixelBufferPoolCreatePixelBuffer() failed")
        
        guard let pixelBuffer = pixelBufferOut else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: data, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        
        context.clear(CGRect(origin: CGPoint(x:0, y:0), size: CGSize(width:size.width, height:size.height)))
        
        let horizontalRatio = size.width / image.size.width
        let verticalRatio = size.height / image.size.height
        let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
        
        let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
        
        let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
        let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0
        
        context.draw(cgImage,in: CGRect(origin: CGPoint(x:x, y:y), size: CGSize(width:newSize.width, height:newSize.height)))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

