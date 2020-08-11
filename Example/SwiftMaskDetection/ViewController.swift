import AVFoundation
import SnapKit
import SwiftMaskDetection
import UIKit


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  // Change this to .back to use the back camera:
  let camera: AVCaptureDevice.Position = .front

  let maxFaces = 8
  let session = AVCaptureSession()
  let output = AVCaptureVideoDataOutput()
  let sessionQueue = DispatchQueue(label: "capture_session")
  let detectionQueue = DispatchQueue(label: "detection", qos: .userInitiated,
                                     attributes: [], autoreleaseFrequency: .workItem)
  let previewView = PreviewView()
  var boxes: [BoundingBox] = []
  var detector: MaskDetectionVideoHelper!

  override func viewDidLoad() {
    super.viewDidLoad()
    detector = MaskDetectionVideoHelper(maskDetector: MaskDetector(maxResults: maxFaces))
    view.backgroundColor = .white
    configureCaptureSession()
    configureUI()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    startCaptureSession()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    stopCaptureSession()
  }

  // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

  func captureOutput(_ output: AVCaptureOutput,
                     didOutput buffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    if let results = try? detector.detectInFrame(buffer) {
      DispatchQueue.main.async {
        self.showResults(results)
      }
    }
  }

  // MARK: UI

  private func configureUI() {
    view.addSubview(previewView)
    previewView.previewLayer.session = session
    for _ in 0..<maxFaces {
      let box = BoundingBox()
      boxes.append(box)
      box.addToLayer(previewView.previewLayer)
    }
    previewView.snp.makeConstraints { make in
      make.center.leading.trailing.equalToSuperview()
      make.height.equalTo(previewView.snp.width).multipliedBy(4.0 / 3.0)
    }
  }

  private func showResults(_ results: [MaskDetector.Result]) {
    for i in 0..<boxes.count {
      if i < results.count {
        let frame = previewView.toViewCoords(results[i].bound, mirrored: camera == .front)
        let label = results[i].status == .mask ? "Mask" : "No Mask"
        boxes[i].show(frame: frame,
                      label: "\(label) \(String(format: "%.2f", results[i].confidence))",
                      color: results[i].status == .mask ? .systemGreen : .red)
      } else {
        boxes[i].hide()
      }
    }
  }

  // MARK: Camera

  private func configureCaptureSession() {
    guard let device = AVCaptureDevice.default(
      .builtInWideAngleCamera, for: .video, position: camera) else {
      print("Failed to acquire camera")
      return
    }
    guard let input = try? AVCaptureDeviceInput(device: device) else {
      print("Failed to create AVCaptureDeviceInput")
      return
    }
    output.videoSettings = [
      String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
    ]
    output.alwaysDiscardsLateVideoFrames = true
    session.beginConfiguration()
    session.sessionPreset = .hd1280x720
    if session.canAddInput(input) {
      session.addInput(input)
    }
    if session.canAddOutput(output) {
      session.addOutput(output)
    }
    output.connection(with: .video)?.videoOrientation = .portrait
    session.commitConfiguration()
    output.setSampleBufferDelegate(self, queue: detectionQueue)
  }

  private func startCaptureSession() {
    sessionQueue.async {
      if !self.session.isRunning {
        self.session.startRunning()
      }
    }
  }

  private func stopCaptureSession() {
    sessionQueue.async {
      if self.session.isRunning {
        self.session.stopRunning()
      }
    }
  }
}
