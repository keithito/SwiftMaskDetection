# SwiftMaskDetection

[![CI Status](https://img.shields.io/travis/keithito/SwiftMaskDetection.svg?style=flat)](https://travis-ci.org/keithito/SwiftMaskDetection)
[![Version](https://img.shields.io/cocoapods/v/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)
[![License](https://img.shields.io/cocoapods/l/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)
[![Platform](https://img.shields.io/cocoapods/p/SwiftMaskDetection.svg?style=flat)](https://cocoapods.org/pods/SwiftMaskDetection)

SwiftMaskDetection is a face mask detection library written in Swift.

It provides provides an interface to [AIZOO's FaceMaskDetection model](https://github.com/AIZOOTech/FaceMaskDetection).
so that face mask detection can easily be run in iPhone and iPad apps.

The model has been converted to CoreML using [coremltools](https://apple.github.io/coremltools/), and
runs at > 30fps on recent iPhones and iPads.


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

## Usage

TODO


## License

SwiftMaskDetection is available under the MIT license. See the LICENSE file for more info.

The face mask detection model is (c) 2020 AIZOOTech and is also available under the
[MIT License](https://github.com/AIZOOTech/FaceMaskDetection/blob/6068769c7a6/LICENSE).
