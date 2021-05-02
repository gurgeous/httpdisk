require_relative 'lib/httpdisk/version'

Gem::Specification.new do |s|
  s.name = 'httpdisk'
  s.version = HTTPDisk::VERSION
  s.authors = ['Adam Doppelt']
  s.email = 'amd@gurge.com'

  s.summary = 'httpdisk - disk cache for faraday'
  s.description = 'httpdisk works with faraday to aggressively cache responses on disk.'
  s.homepage = 'http://github.com/gurgeous/httpdisk'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.7.0'

  # what's in the gem?
  s.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { _1.match(%r{^test/}) }
  end
  s.bindir = 'bin'
  s.executables = s.files.grep(%r{^#{s.bindir}/}) { File.basename(_1) }
  s.require_paths = ['lib']

  # gem dependencies
  s.add_dependency 'faraday', '~> 1.4'
  s.add_dependency 'faraday-cookie_jar', '~> 0.0'
  s.add_dependency 'faraday_middleware', '~> 1.0'
  s.add_dependency 'slop', '~> 4.8'
end
