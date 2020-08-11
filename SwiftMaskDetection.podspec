Pod::Spec.new do |s|
  s.name             = 'SwiftMaskDetection'
  s.version          = '0.1.0'
  s.summary          = 'A face mask detection library written in Swift.'
  s.homepage         = 'https://github.com/keithito/SwiftMaskDetection'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Keith Ito' => 'kito@kito.us' }
  s.source           = { :git => 'https://github.com/keithito/SwiftMaskDetection.git', :tag => s.version.to_s }
  s.source_files     = 'SwiftMaskDetection/Classes/**/*.{swift,mlmodel}'
  s.resources        = 'SwiftMaskDetection/Classes/**/*.json'
  s.pod_target_xcconfig   = { 'COREML_CODEGEN_LANGUAGE' => 'Swift' }
  s.swift_version    = '5.0'
  s.ios.deployment_target = '10.0'
  s.description      = <<-END
SwiftMaskDetection is a port of the AIZOO FaceMaskDetection model to CoreML, with a Swift interface.
It is capable of running in real-time on the iPhone and iPad.
                       END
end
