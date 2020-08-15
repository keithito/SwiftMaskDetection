// Copyright © 2020 Keith Ito. MIT License.
//
// Portions of this file are based on https://github.com/AIZOOTech/FaceMaskDetection
// Copyright (c) 2020 AIZOOTech. MIT License.
import AVFoundation
import CoreImage
import Vision


/// Detects faces in an image and whether or not the face has a mask on it.
@available(iOS 13.0, *)
public class MaskDetector {
  public enum Status {
    /// The person is wearing a mask
    case mask
    /// The person is not wearing a mask
    case noMask
  }

  /// A face mask detection result
  public struct Result {
    /// The status of the detection (e.g. mask/noMask)
    public let status: Status

    /// The bounding box of the face in normalized coordinates (the top-left corner of the image
    /// is [0, 0], and the bottom-right corner is [1, 1]).
    public let bound: CGRect

    /// Value between 0 and 1 representing the confidence in the result
    public let confidence: Float
  }

  /// Images sent to the model must have a height and width equal to this.
  public static let InputImageSize = 260

  private let minConfidence: Float
  private let iouThreshold: Float
  private let maxResults: Int
  // Don't return a result unless the best class confidence is a factor of this better than the
  // other class confidence. TODO: Consider making this a parameter to init?
  private let margin: Float = 5
  private let mlModel = MaskModel()
  private let model: VNCoreMLModel
  private let anchors = loadAnchors()

  /// - Parameters:
  ///   - minConfidence: minimum confidence for returned results
  ///   - iouThreshold: intersection over union threshold for non-max suppression
  ///   - maxResults: maximum number of results to return
  public init(minConfidence: Float=0.8, maxResults: Int=10, iouThreshold: Float=0.2) {
    self.minConfidence = minConfidence
    self.maxResults = maxResults
    self.iouThreshold = iouThreshold
    model = try! VNCoreMLModel(for: mlModel.model)
  }

  /// Detects faces with masks or not in the input image. This blocks while detection is
  /// being performed and should not be called on the main thread.
  /// - Parameters:
  ///   - cvPixelBuffer: A 260x260 CVPixelBuffer
  ///   - orientation: The orientation of the input image (default .up)
  /// - Returns: An array of detection results, one for each face
  public func detectMasks(cvPixelBuffer: CVPixelBuffer,
                          orientation: CGImagePropertyOrientation = .up) throws -> [Result] {
    return try detectMasks(handler: VNImageRequestHandler(cvPixelBuffer: cvPixelBuffer,
                                                          orientation: orientation))
  }

  /// Detects faces with masks or not in the input image. This blocks while detection is
  /// being performed and should not be called on the main thread.
  /// - Parameters:
  ///   - cgImage: A 260x260 CGImage
  ///   - orientation: The orientation of the input image (default .up)
  /// - Returns: An array of detection results, one for each face
  public func detectMasks(cgImage: CGImage,
                          orientation: CGImagePropertyOrientation = .up) throws -> [Result] {
    return try detectMasks(handler: VNImageRequestHandler(cgImage: cgImage,
                                                          orientation: orientation))
  }

  /// Detects faces with masks or not in the input image. This blocks while detection is
  /// being performed and should not be called on the main thread.
  /// - Parameters:
  ///   - ciImage: A 260x260 CIImage
  ///   - orientation: The orientation of the input image (default .up)
  /// - Returns: An array of detection results, one for each face
  public func detectMasks(ciImage: CIImage,
                          orientation: CGImagePropertyOrientation = .up) throws -> [Result] {
    return try detectMasks(handler: VNImageRequestHandler(ciImage: ciImage,
                                                          orientation: orientation))
  }

  private func detectMasks(handler: VNImageRequestHandler) throws -> [Result] {
    let request = VNCoreMLRequest(model: model)
    try handler.perform([request])
    guard let results = request.results as? [VNCoreMLFeatureValueObservation],
      results.count == 2,
      results[0].featureName == "output_bounds",
      results[1].featureName == "output_scores",
      let boundOutputs = results[0].featureValue.multiArrayValue,
      let confOutputs = results[1].featureValue.multiArrayValue,
      confOutputs.dataType == .float32,
      boundOutputs.dataType == .float32,
      confOutputs.shape == [1, NSNumber(value: anchors.count), 2],
      boundOutputs.shape == [1, NSNumber(value: anchors.count), 4] else {
      print("Unexpected result from CoreML!")
      return []
    }

    // Model has 2 outputs:
    //  1. Confidences [1,5972,2]: confidence for each anchor for each class (mask, no_mask)
    //  2. Bounds [1,5972,4]: encoded bounding boxes for each anchor (see decodeBound)
    let confPtr = UnsafeMutablePointer<Float>(OpaquePointer(confOutputs.dataPointer))
    let boundPtr = UnsafeMutablePointer<Float>(OpaquePointer(boundOutputs.dataPointer))
    let confStrides = confOutputs.strides.map { $0.intValue }
    let boundStrides = boundOutputs.strides.map { $0.intValue }
    var detections: [Result] = []
    for i in 0..<confOutputs.shape[1].intValue {
      let maskConf = confPtr[i * confStrides[1]]
      let noMaskConf = confPtr[i * confStrides[1] + 1 * confStrides[2]]
      if max(maskConf, noMaskConf) > minConfidence {
        let offset = i * boundStrides[1]
        let rawBound: [Float] = [
          boundPtr[offset],
          boundPtr[offset + 1 * boundStrides[2]],
          boundPtr[offset + 2 * boundStrides[2]],
          boundPtr[offset + 3 * boundStrides[2]],
        ]
        let bound = decodeBound(anchor: anchors[i], rawBound: rawBound)
        if maskConf > noMaskConf * margin {
          detections.append(Result(status: .mask, bound: bound, confidence: maskConf))
        } else if noMaskConf > maskConf * margin {
          detections.append(Result(status: .noMask, bound: bound, confidence: noMaskConf))
        }
      }
    }
    return nonMaxSuppression(inputs: detections,
                             iouThreshold: iouThreshold,
                             maxResults: maxResults)
  }
}

// Anchor bounds as generated by the python code in evaluate.py. These must match the anchors that
// the model was trained with. We dump them from the python code and load them here.
@available(iOS 13.0, *)
private func loadAnchors() -> [[Double]] {
  let path = Bundle(for: MaskDetector.self).path(forResource: "anchors", ofType: "json")!
  let data = try! Data(contentsOf: URL(fileURLWithPath: path))
  let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
  return json["anchors"] as! [[Double]]
}

// Decodes the bound output from the model based on the anchor it is for. The model output is a
// 4D vector where the first 2 components are the delta from the anchor center to the bound center
// and the last 2 are the log of the ratio of the bound size to the anchor size.
private func decodeBound(anchor: [Double], rawBound: [Float]) -> CGRect {
  let anchorW = anchor[2] - anchor[0]
  let anchorH = anchor[3] - anchor[1]
  let anchorCenterX = anchor[0] + 0.5 * anchorW
  let anchorCenterY = anchor[1] + 0.5 * anchorH
  let cx = Double(rawBound[0]) * 0.1 * anchorW + anchorCenterX
  let cy = Double(rawBound[1]) * 0.1 * anchorH + anchorCenterY
  let w = exp(Double(rawBound[2]) * 0.2) * anchorW
  let h = exp(Double(rawBound[3]) * 0.2) * anchorH
  return CGRect(x: CGFloat(cx - w / 2),
                y: CGFloat(cy - h / 2),
                width: CGFloat(w),
                height: CGFloat(h))
}


// Performs non-max supression with a configurable overlap threshold.
@available(iOS 13.0, *)
private func nonMaxSuppression(inputs: [MaskDetector.Result],
                               iouThreshold: Float,
                               maxResults: Int) -> [MaskDetector.Result] {
  var outputs: [MaskDetector.Result] = []
  let inputsByConfidenceDesc = inputs.sorted { $0.confidence > $1.confidence }
  for result in inputsByConfidenceDesc {
    if !hasOverlap(result, with: outputs, iouThreshold: iouThreshold) {
      outputs.append(result)
      if outputs.count >= maxResults {
        break
      }
    }
  }
  return outputs;
}

@available(iOS 13.0, *)
private func hasOverlap(_ result: MaskDetector.Result,
                        with others: [MaskDetector.Result],
                        iouThreshold: Float) -> Bool {
  let resultArea = result.bound.width * result.bound.height
  for other in others {
    let intersection = areaOfIntersection(result.bound, other.bound)
    if intersection > 0 {
      let union = resultArea + other.bound.width * other.bound.height - intersection
      if Float(intersection / union) >= iouThreshold {
        return true
      }
    }
  }
  return false
}

private func areaOfIntersection(_ a: CGRect, _ b: CGRect) -> CGFloat {
  let maxMinX = max(a.minX, b.minX)
  let minMaxX = min(a.maxX, b.maxX)
  let maxMinY = max(a.minY, b.minY)
  let minMaxY = min(a.maxY, b.maxY)
  return max(0, minMaxX - maxMinX) * max(0, minMaxY - maxMinY)
}
