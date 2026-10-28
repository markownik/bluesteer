#!/usr/bin/env ruby
# Generates UIDriver.xcodeproj (a lone XCUITest bundle) with the xcodeproj gem
# that ships with CocoaPods, so no hand-written pbxproj lives in the repo.
require 'xcodeproj'

dir = File.expand_path(File.dirname(__FILE__))
team = ARGV[0] or abort "usage: make-project.rb <DEVELOPMENT_TEAM>"
path = File.join(dir, 'UIDriver.xcodeproj')
FileUtils.rm_rf(path)

project = Xcodeproj::Project.new(path)
target = project.new_target(:ui_test_bundle, 'UIDriverUITests', :ios, '16.0')
group = project.new_group('UIDriverUITests', 'UIDriverUITests')
target.add_file_references([group.new_file('UIDriverUITests.swift')])
target.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.bluesteer.uidriver'
  c.build_settings['DEVELOPMENT_TEAM'] = team
  c.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  c.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  c.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  c.build_settings['MARKETING_VERSION'] = '1.0'
end
project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(path, 'UIDriverUITests', true)
puts "wrote #{path}"
