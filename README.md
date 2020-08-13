# SwiftMaskDetection

<!--
[![CI Status](https://img.shields.io/travis/keithito/SwiftMaskDetection.svg?style=flat)](https://travis-ci.org/keithito/SwiftMaskDetection)
-->
[![Version](https://img.shields.io/cocoapods/v/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)
[![License](https://img.shields.io/cocoapods/l/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)
[![Platform](https://img.shields.io/cocoapods/p/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)


SwiftMaskDetection is a face mask detection library with a Swift interface.

It is a port of [AIZOO's FaceMaskDetection model](https://github.com/AIZOOTech/FaceMaskDetection) to
CoreML. The model runs at over 30fps on recent iPhones and iPads. For more information on the model and training data,
please see https://github.com/AIZOOTech/FaceMaskDetection (AIZOO did all the hard work).

## Demo

![Demo video](https://data.keithito.com/maskdetection/detection1.gif)
![Demo video](https://data.keithito.com/maskdetection/detection2.gif)

To run the demo:

  1. Make sure you have [Xcode](https://developer.apple.com/support/xcode/) and [CocoaPods](https://cocoapods.org/).
  
  2. Clone this repo and open the example project:
     ```
     git clone https://github.com/keithito/SwiftMaskDetection.git
     cd Example 
     pod install
     open SwiftMaskDetection.xcworkspace
     ```
     
  3. Run the project from XCode on a device (it needs the camera)
      * If you see an error that signing needs a development team, open the "SwiftMaskDetection" project, click on
        the "Signing & Capabilities" tab, and select an option from the "Team" menu.
  

## Installation

SwiftMaskDetection is available through [CocoaPods](https://cocoapods.org). To install it, add the following
line to your Podfile:

```ruby
pod 'SwiftMaskDetection'
```


If you don't use CocoaPods, you can simply copy the files in [SwiftMaskDetection/Classes](https://github.com/keithito/SwiftMaskDetection/tree/master/SwiftMaskDetection/Classes) into your Xcode project.


## Usage

### Images

To recognize an image:

```swift
import SwiftMaskDetection

let detector = MaskDetector()
let image = UIImage(named: "my_photo")!
if let results = try? detector.detectMasks(cgImage: image.cgImage!) {
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



## License

SwiftMaskDetection is available under the MIT license. See the LICENSE file for more info.

The face mask detection model is (c) 2020 AIZOOTech and is also available under the
[MIT License](https://github.com/AIZOOTech/FaceMaskDetection/blob/6068769c7a6/LICENSE).
