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
    
    var photo: UIImage?
    var durationInSeconds: Double?
    var targetSize: CGSize?
    
    var outputUrl: URL?
    var error: Error?
    
    private lazy var videoSettings = [
        AVVideoCodecKey : AVVideoCodecType.h264,
        AVVideoWidthKey : targetSize.valOrExpFail?.width ?? 0,
        AVVideoHeightKey : targetSize.valOrExpFail?.height ?? 0
        ] as [String : Any]
    
    private lazy var sourceBufferAttributes = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey: targetSize.valOrExpFail?.width.flt ?? 0,
        kCVPixelBufferHeightKey: targetSize.valOrExpFail?.height.flt ?? 0,
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as [String : Any]
    
    private let fileType: AVFileType = .m4v
    
    override func main() {
        guard var photo = self.photo, let durationInSeconds = self.durationInSeconds, let targetSize = self.targetSize  else { return }
        
        // TODO: uncomment later
//        photo = (photo.ciImageWithCorrectOrientation?.renderUIImage()).imageOrDummyAndFailExpectatio
        
        let targetUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension(fileType.fileExtension)
        let vidDuration = CMTime(seconds: durationInSeconds.dbl, preferredTimescale: 600)
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        do {
            let videoWriter = try AVAssetWriter(outputURL: targetUrl, fileType: fileType)
            videoWriter.add(videoWriterInput)
            guard videoWriter.startWriting() else { expectationFail(); return }
            
            videoWriter.startSession(atSourceTime: CMTime.zero)
            
            guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool, let imagePixelBuffer = pixelBufferFromImage(image: photo, pixelBufferPool: pixelBufferPool, size: targetSize) else { expectationFail(); return }
            
            expect(videoWriterInput.isReadyForMoreMediaData)
            pixelBufferAdaptor.append(imagePixelBuffer, withPresentationTime: CMTime.zero)
            pixelBufferAdaptor.append(imagePixelBuffer, withPresentationTime: vidDuration)
            
            videoWriterInput.markAsFinished()
            videoWriter.endSession(atSourceTime: vidDuration)
            
            let sema = DispatchSemaphore(value: 0)
            
            videoWriter.finishWriting {
                defer { sema.signal() }
                guard videoWriter.status == .completed else { expectationFail(); self.error = videoWriter.error; return }
                self.outputUrl = targetUrl
            }
            
            sema.wait()
        }
        catch {
            expectationFail()
            self.error = error
        }
    }
    
    func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage, let pixelBuffer = pixelBufferPool.createBuffer() else { expectationFail(); return nil }
        
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
        context.draw(cgImage, in: CGRect(origin: CGPoint(x: x, y: y), size: newSize))
        
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
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self, &res) == kCVReturnSuccess else { expectationFail(); return nil }
        return res
    }
}

fileprivate extension AVFileType {
    var fileExtension: String {
        switch self {
        case .m4v: return "m4v"
        case .mov: return "mov"
        default: expectationFail(); return "mov"
        }
    }
}
