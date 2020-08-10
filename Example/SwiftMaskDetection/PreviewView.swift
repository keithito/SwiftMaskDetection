// Copyright © 2020 Toolbox AI. All rights reserved.
import AVFoundation
import UIKit


class PreviewView: UIView {
  var previewLayer: AVCaptureVideoPreviewLayer {
    return layer as! AVCaptureVideoPreviewLayer
  }

  init() {
    super.init(frame: .zero)
    previewLayer.videoGravity = .resizeAspectFill
  }

  required init?(coder: NSCoder) {
    fatalError()
  }

  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }

  /// Converts normalized image coordinates to coordinates in this view, taking into account that
  /// some of the image may be cropped due to .resizeAspectFill gravity.
  func toViewCoords(_ rect: CGRect, mirrored: Bool) -> CGRect {
    var bound = rect
    if mirrored {
      // Flip x-axis
      bound = bound
        .applying(CGAffineTransform(scaleX: -1, y: 1))
        .applying(CGAffineTransform(translationX: 1, y: 0))
    }

    // Adjust to match the aspect ratio of the preview
    let inputAspect: CGFloat = 9 / 16
    let viewAspect = bounds.width / bounds.height
    if inputAspect >= viewAspect {
      bound = bound
        .applying(CGAffineTransform(scaleX: inputAspect / viewAspect, y: 1))
        .applying(CGAffineTransform(translationX: 0.5 * (1 - inputAspect / viewAspect), y: 0))
    } else {
      bound = bound
        .applying(CGAffineTransform(scaleX: 1, y: viewAspect / inputAspect))
        .applying(CGAffineTransform(translationX: 0, y: 0.5 * (1 - viewAspect / inputAspect)))
    }

    // Scale to view size
    return bound.applying(CGAffineTransform(scaleX: bounds.width, y: bounds.height))
  }
}
