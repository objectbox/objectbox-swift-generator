# Uncomment this line to define a global platform for your project
platform :osx, '10.13'

workspace 'Sourcery.xcworkspace'
use_frameworks!
inhibit_all_warnings!


# Define it just once, since it's used in multiple places
# 0.32.0 is the first version with inproc communication option to SourceKit
# and therefore the minimum version required to run this Sourcery version in the sandbox of a Swift Package Plugin
source_kitten_framework_version = '0.32.0'


def meta
  pod 'SwiftLint'
end

def test_pods
  pod 'Quick'
  pod 'Nimble'
end

def pathkit
  pod 'PathKit', '0.9.2'
end

target 'TemplatesTests' do
  project 'Templates/Templates.xcodeproj'
  meta
  test_pods
end
target 'CodableContextTests' do
  project 'Templates/Templates.xcodeproj'
  meta
  test_pods
end

target 'Sourcery' do
  pod 'Stencil', '0.13.1'
  pod 'StencilSwiftKit', '2.7.0'
  pod 'Commander', '0.9.2' # lower versions show compilor issues with some the command<A:ArgumentConvertible... > functions. Seems related to the new string conversion we see on other places
  pathkit
  pod "xcproj", :git =>'git@github.com:tuist/xcodeproj.git', :tag => '4.3.1'
  pod 'SourceKittenFramework', source_kitten_framework_version
  pod 'Yams' , '4.0.6' # Mirror SourceKittens requirement, since this is the driving dependency

  target 'SourceryTests' do
    inherit! :search_paths
    test_pods
  end
end

target 'SourceryJS' do
  pathkit
end

target 'SourcerySwift' do
  pathkit
end

target 'SourceryUtils' do
  pathkit
end

target 'SourceryFramework' do
  pathkit
  pod 'SourceKittenFramework', source_kitten_framework_version
end

# This is a temporary workaround to make all dependencies target macOS 10.13
# To replace this dependencies should be updated to versions that target 10.13+.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.13'
    end
  end
end
