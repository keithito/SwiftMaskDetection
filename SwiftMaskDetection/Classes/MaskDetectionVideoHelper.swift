// Copyright © 2020 Keith Ito. MIT License.
import AVFoundation
import CoreImage


/// Helper to assist with real-time detection in a video stream. You can call this from the
/// captureOutput function in a AVCaptureVideoDataOutputSampleBufferDelegate to feed frames
/// to the MaskDetector. See the Example for usage.
@available(iOS 13.0, *)
public class MaskDetectionVideoHelper {
  /// Controls how input images are resized to square 260x260 images for the model.
  public enum ResizeMode {
    /// Images are cropped along the longer dimension, with equal amounts removed from each side.
    /// This doesn't distort the image, but recognition will only happen in the center square.
    case centerCrop
    /// Images are stretched to be square. Recognition can take place in the entire image, but
    /// there will be distortion, which may affect model performance.
    case stretch
  }

  private let resizeMode: ResizeMode
  private let maskDetector: MaskDetector

  /// - Parameters:
  ///   - maskDetector: the MaskDetector to use for detection
  ///   - resizeMode: controls how input images are made square if they are not already
  public init(maskDetector: MaskDetector, resizeMode: ResizeMode = .centerCrop) {
    self.maskDetector = maskDetector
    self.resizeMode = resizeMode
  }

  /// Runs the detector on the given CMSampleBuffer.
  /// This blocks while detection is being performed and should not be called on the main thread.
  public func detectInFrame(_ buffer: CMSampleBuffer) throws -> [MaskDetector.Result] {
    guard let image = CMSampleBufferGetImageBuffer(buffer) else { return [] }
    let width = CVPixelBufferGetWidth(image)
    let height = CVPixelBufferGetHeight(image)
    let transform: CGAffineTransform
    if resizeMode == .centerCrop  {
      let scale = CGFloat(MaskDetector.InputImageSize) / CGFloat(min(width, height))
      transform = CGAffineTransform(scaleX: scale, y: scale)
    } else {
      let scaleX = CGFloat(MaskDetector.InputImageSize) / CGFloat(width)
      let scaleY = CGFloat(MaskDetector.InputImageSize) / CGFloat(height)
      transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    }

    let ciImage = CIImage(cvPixelBuffer: image)
      .transformed(by: transform, highQualityDownsample: true)
    let results = try maskDetector.detectMasks(ciImage: ciImage)

    if resizeMode == .centerCrop {
      // Transform bounding box coordinates back to the input image
      let inputAspect = CGFloat(width) / CGFloat(height)
      return results.map { res in
        let bound = res.bound
          .applying(CGAffineTransform(scaleX: 1, y: inputAspect))
          .applying(CGAffineTransform(translationX: 0, y: 0.5 * (1 - inputAspect)))
        return MaskDetector.Result(status: res.status, bound: bound, confidence: res.confidence)
      }
    } else {
      return results
    }
  }
}
