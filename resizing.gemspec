# frozen_string_literal: true

require_relative 'lib/resizing/version'

Gem::Specification.new do |spec|
  spec.name          = 'resizing'
  spec.version       = Resizing::VERSION
  spec.authors       = ['Junichiro Kasuya']
  spec.email         = ['junichiro.kasuya@gmail.com']

  spec.summary       = 'Client and utilities for Resizing'
  spec.description   = 'Client and utilities for Resizing '
  spec.homepage      = 'https://github.com/jksy/resizing-gem'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/jksy/resizing-gem.'
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0")
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.add_runtime_dependency 'faraday', '~> 2.3'
  spec.add_runtime_dependency 'faraday-multipart'
  spec.add_development_dependency 'rails', '~> 6.0'
  spec.add_development_dependency 'carrierwave', '~> 1.3.2'
  spec.add_development_dependency 'fog-aws'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-ci'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'vcr'
end
