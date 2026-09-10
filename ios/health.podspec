#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'health'
  s.version          = '13.3.2'
  s.summary          = 'Wrapper for Apple\'s HealthKit on iOS and Google\'s Health Connect on Android.'
  s.description      = <<-DESC
Wrapper for Apple's HealthKit on iOS and Google's Health Connect on Android.
                       DESC
  s.homepage         = 'https://pub.dev/packages/health'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Copenhagen Research Platform at DTU' => 'support@carp.dk' }
  s.source           = { :path => '.' }
  s.source_files = 'health/Sources/health/**/*.swift'
  s.dependency 'Flutter'

  s.ios.deployment_target = '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
