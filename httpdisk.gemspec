require_relative "lib/httpdisk/version"

Gem::Specification.new do |s|
  s.name = "httpdisk"
  s.version = HTTPDisk::VERSION
  s.authors = ["Adam Doppelt"]
  s.email = "amd@gurge.com"

  s.summary = "httpdisk - disk cache for faraday"
  s.description = "httpdisk works with faraday to aggressively cache responses on disk."
  s.homepage = "http://github.com/gurgeous/httpdisk"
  s.license = "MIT"
  s.required_ruby_version = ">= 3.2.0"
  s.metadata["rubygems_mfa_required"] = "true"

  # what's in the gem?
  s.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { _1.match(%r{^test/}) }
  end
  s.bindir = "bin"
  s.executables = s.files.grep(%r{^#{s.bindir}/}) { File.basename(_1) }
  s.require_paths = ["lib"]

  # gem dependencies
  s.add_dependency "base64", "~> 0.1" # required for 3.4
  s.add_dependency "content-type", "~> 0.0"
  s.add_dependency "faraday", "~> 2.13"
  s.add_dependency "faraday-cookie_jar", "~> 0.0"
  s.add_dependency "faraday-follow_redirects", "~> 0.3"
  s.add_dependency "ostruct", "~> 0.6" # required for 3.5
  s.add_dependency "slop", "~> 4.10"
end
