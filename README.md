# SwiftMaskDetection

[![CI Status](https://img.shields.io/travis/keithito/SwiftMaskDetection.svg?style=flat)](https://travis-ci.org/keithito/SwiftMaskDetection)
[![Version](https://img.shields.io/cocoapods/v/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)
[![License](https://img.shields.io/cocoapods/l/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)
[![Platform](https://img.shields.io/cocoapods/p/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)

SwiftMaskDetection is a face mask detection library written in Swift.

It ports [AIZOO's FaceMaskDetection model](https://github.com/AIZOOTech/FaceMaskDetection) to
CoreML and provides a Swift interface to it for easy use in iOS apps.

The model was converted to CoreML with the [convert.py](./Converter/convert.py) script. It runs at
over 30fps on recent iPhones and iPads. For more information on the model and training data,
please see https://github.com/AIZOOTech/FaceMaskDetection.


## Usage


### Images

To recognize an image:

```swift
import SwiftMaskDetection

let detector = MaskDetector()
let image = UIImage(named: "my_photo")!
if let results = try detector.detectMasks(cgImage: image.cgImage!) {
  // Do something with the results.
}
```

The image **must be 260x260 pixels**. `detectMasks` supports `CGImage`, `CIImage`, and `CVPixelBuffer` inputs and
returns an array of `Results`, one for each detected face:

```swift
public struct Result {
  /// The status of the detection (.mask or .noMask)
  public let status: Status

  /// The bounding box of the face in normalized coordinates (the top-left corner of the image
  /// is [0, 0], and the bottom-right corner is [1, 1]).
  public let bound: CGRect

  /// Value between 0 and 1 representing the confidence in the result
  public let confidence: Float
}
```


### Video

`MaskDetectionVideoHelper` may come in handy for running on live video. First, create the helper:

```swift
let helper = MaskDetectionVideoHelper(maskDetector: MaskDetector())
```

Then call `detectInFrame` on each video frame:

```swift
if let results = try? detector.detectInFrame(cmSampleBuffer) {
  // Do something with the results.
}

```

You don't need to resize the image to 260x260; the helper does that for you. See the example app's
[ViewController](./Example/SwiftMaskDetection/ViewController.swift) for a complete example.



## Requirements
  * iOS 13 or later


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory.


## Installation

SwiftMaskDetection is available through [CocoaPods](https://cocoapods.org). To install
it, add the following line to your Podfile:

```ruby
pod 'SwiftMaskDetection'
```


## License

SwiftMaskDetection is available under the MIT license. See the LICENSE file for more info.

The face mask detection model is (c) 2020 AIZOOTech and is also available under the
[MIT License](https://github.com/AIZOOTech/FaceMaskDetection/blob/6068769c7a6/LICENSE).
