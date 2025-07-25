Pod::Spec.new do |s|
  s.name         = 'SQLiteAdapter'
  s.version      = '0.8.1'
  s.homepage     = 'https://github.com/denissimon/SQLiteAdapter'
  s.authors      = { 'Denis Simon' => 'denis.v.simon@gmail.com' }
  s.summary      = 'A simple wrapper around SQLite3'
  s.license      = { :type => 'MIT' }

  s.swift_versions = ['5']
  s.ios.deployment_target = "12.0"
  s.osx.deployment_target = "10.13"
  s.watchos.deployment_target = "4.0"
  s.tvos.deployment_target = "12.0"
  s.source       =  { :git => 'https://github.com/denissimon/SQLiteAdapter.git', :tag => s.version.to_s }
  s.source_files = 'Sources/**/*.swift'
  s.frameworks  = "Foundation"
end
