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
    
    private lazy var videoSettings = [
        AVVideoCodecKey : AVVideoCodecType.h264,
        AVVideoWidthKey : photo.size.width,
        AVVideoHeightKey : photo.size.height
        ] as [String : Any]
    
    private lazy var sourceBufferAttributes = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey: Float(photo.size.width),
        kCVPixelBufferHeightKey: Float(photo.size.height),
        kCVPixelBufferCGImageCompatibilityKey: NSNumber(value: true),
        kCVPixelBufferCGBitmapContextCompatibilityKey: NSNumber(value: true)
        ] as [String : Any]
    
    override func main() {
        let dir = NSTemporaryDirectory() + UUID().uuidString + ".m4v"
        let vidDuration = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
        
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        do {
            let videoWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: dir), fileType: .m4v)
            videoWriter.add(videoWriterInput)
            guard videoWriter.startWriting() else { assert(false); return }
            
            videoWriter.startSession(atSourceTime: CMTime.zero)
            
            guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool, let imagePixelBuffer = pixelBufferFromImage(image: photo, pixelBufferPool: pixelBufferPool, size: photo.size) else { assert(false); return }
            
            assert(videoWriterInput.isReadyForMoreMediaData)
            pixelBufferAdaptor.append(imagePixelBuffer, withPresentationTime: CMTime.zero)
            pixelBufferAdaptor.append(imagePixelBuffer, withPresentationTime: vidDuration)
            
            videoWriterInput.markAsFinished()
            videoWriter.endSession(atSourceTime: vidDuration)
            
            let semaphore = DispatchSemaphore(value: 0)
            
            videoWriter.finishWriting {
                defer { semaphore.signal() }
                guard videoWriter.status == .completed else { self.outputError = videoWriter.error; return }
                self.outputURL = URL(fileURLWithPath: dir)
            }
            
            semaphore.wait()
        }
        catch {
            self.outputError = error
        }
    }
    
    func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage, let pixelBuffer = pixelBufferPool.createBuffer() else { assert(false); return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        guard let context = createContext(pixelBuffer: pixelBuffer, size: size) else { return nil }
        
        let horizontalRatio = size.width / image.size.width
        let verticalRatio = size.height / image.size.height
        let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
        
        let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
        
        let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
        let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0
        
        context.clear(CGRect(origin: .zero, size: size))
        context.draw(cgImage, in: CGRect(origin: CGPoint(x:x, y:y), size: CGSize(width: newSize.width, height: newSize.height)))
        
        return pixelBuffer
    }
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    
    func createContext(pixelBuffer: CVPixelBuffer, size: CGSize) -> CGContext? {
        let baseAddr = CVPixelBufferGetBaseAddress(pixelBuffer)
        return CGContext(data: baseAddr, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    }
}

// MARK: -

extension CVPixelBufferPool {
    
    func createBuffer() -> CVPixelBuffer? {
        var res: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self, &res) == kCVReturnSuccess else { assert(false); return nil }
        return res
    }
}
