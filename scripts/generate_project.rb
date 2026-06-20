#!/usr/bin/env ruby
# Generates etch.xcodeproj (app target + linked local etchKit package).
# Re-runnable: regenerates the project from scratch each time.
require 'xcodeproj'
require 'fileutils'

repo = File.expand_path('..', __dir__)
proj_dir = File.join(repo, 'etch')
proj_path = File.join(proj_dir, 'etch.xcodeproj')

FileUtils.rm_rf(proj_path)
project = Xcodeproj::Project.new(proj_path)

DEPLOYMENT = '26.0'
BUNDLE_ID  = 'com.descifrador.etch'

# ---- App target ----------------------------------------------------------
app = project.new_target(:application, 'etch', :ios, DEPLOYMENT)

# Source + resource files live under etch/etch
app_root = File.join(proj_dir, 'etch')
group = project.main_group.new_group('etch', 'etch')

swift_files = Dir.glob(File.join(app_root, '**', '*.swift')).sort
swift_files.each do |path|
  rel = path.sub(app_root + '/', '')
  ref = group.new_reference(rel)
  app.add_file_references([ref])
end

# Asset catalog (resource)
assets = File.join(app_root, 'Resources', 'Assets.xcassets')
if File.exist?(assets)
  ref = group.new_reference('Resources/Assets.xcassets')
  app.add_resources([ref])
end

# Entitlements (reference only, not compiled)
group.new_reference('etch.entitlements')

# ---- Local Swift package: etchKit -------------------------------------
local_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local_ref.relative_path = '../etchKit'
project.root_object.package_references << local_ref

product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = local_ref
product.product_name = 'etchKit'
app.package_product_dependencies << product

build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product
app.frameworks_build_phase.files << build_file

# ---- UI test target ------------------------------------------------------
uitests = project.new_target(:ui_test_bundle, 'etchUITests', :ios, DEPLOYMENT)
uitest_root = File.join(proj_dir, 'etchUITests')
uitest_group = project.main_group.new_group('etchUITests', 'etchUITests')
Dir.glob(File.join(uitest_root, '**', '*.swift')).sort.each do |path|
  rel = path.sub(uitest_root + '/', '')
  uitests.add_file_references([uitest_group.new_reference(rel)])
end
uitests.add_dependency(app)
uitests.build_configurations.each do |config|
  s = config.build_settings
  s['IPHONEOS_DEPLOYMENT_TARGET']  = DEPLOYMENT
  s['SWIFT_VERSION']               = '6.0'
  s['PRODUCT_BUNDLE_IDENTIFIER']   = 'com.descifrador.etchUITests'
  s['GENERATE_INFOPLIST_FILE']     = 'YES'
  s['TEST_TARGET_NAME']            = 'etch'
  s['CODE_SIGNING_ALLOWED']        = 'NO'
  s['TARGETED_DEVICE_FAMILY']      = '1,2'
end

# ---- Build settings ------------------------------------------------------
app.build_configurations.each do |config|
  s = config.build_settings
  s['IPHONEOS_DEPLOYMENT_TARGET']            = DEPLOYMENT
  s['SWIFT_VERSION']                          = '6.0'
  s['SWIFT_STRICT_CONCURRENCY']               = 'complete'
  s['SWIFT_UPCOMING_FEATURE_FLAGS']           = ''
  s['PRODUCT_BUNDLE_IDENTIFIER']              = BUNDLE_ID
  s['PRODUCT_NAME']                           = '$(TARGET_NAME)'
  s['GENERATE_INFOPLIST_FILE']                = 'YES'
  s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  s['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
  s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  s['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait'
  s['INFOPLIST_KEY_UISupportedInterfaceOrientations~ipad'] =
    'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  s['ASSETCATALOG_COMPILER_APPICON_NAME']     = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['CODE_SIGN_ENTITLEMENTS']                 = 'etch/etch.entitlements'
  s['CODE_SIGN_STYLE']                        = 'Automatic'
  s['CODE_SIGNING_REQUIRED']                  = 'NO'
  s['CODE_SIGNING_ALLOWED']                   = 'NO'
  s['TARGETED_DEVICE_FAMILY']                 = '1,2'
  s['ENABLE_PREVIEWS']                        = 'YES'
  s['SWIFT_EMIT_LOC_STRINGS']                 = 'YES'
  s['CURRENT_PROJECT_VERSION']                = '1'
  s['MARKETING_VERSION']                      = '1.0'
end

# Project-level Swift version
project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '6.0'
end

project.save

# ---- Shared scheme with a test action -----------------------------------
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(uitests)
scheme.set_launch_target(app) if scheme.respond_to?(:set_launch_target)
scheme.launch_action.buildable_product_runnable =
  Xcodeproj::XCScheme::BuildableProductRunnable.new(app, 0)
scheme.save_as(proj_path, 'etch', true)

puts "Wrote #{proj_path}"
puts "App sources: #{swift_files.size} swift files"
