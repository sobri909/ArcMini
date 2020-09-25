platform :ios, '13.2'
use_frameworks!

target 'Arc Mini' do

  # Arc Mini development follows the LocoKit develop branch, not the stable releases
  pod 'LocoKit', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'develop'
  pod 'LocoKitCore', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'develop'

  # uncomment this line if you're using a local copy of LocoKit 
  # pod 'LocoKit', :path => '~/Projects/LocoKit'
end

target 'RecordersWidgetExtension' do
  # Arc Mini development follows the LocoKit develop branch, not the stable releases
  pod 'LocoKit', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'develop'
  pod 'LocoKitCore', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'develop'

  # uncomment this line if you're using a local copy of LocoKit 
  # pod 'LocoKit', :path => '~/Projects/LocoKit'
end

target 'CurrentItemWidgetExtension' do
  # Arc Mini development follows the LocoKit develop branch, not the stable releases
  pod 'LocoKit', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'develop'
  pod 'LocoKitCore', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'develop'

  # uncomment this line if you're using a local copy of LocoKit 
  # pod 'LocoKit', :path => '~/Projects/LocoKit'
end

# Set Upsurge SWIFT_VERSION to 4.2
post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      if target.name == "Upsurge"
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_VERSION'] = '4.2'
        end
      end
    end
  end
end
