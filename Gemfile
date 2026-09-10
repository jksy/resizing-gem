# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in resizing.gemspec
gemspec

# Allow testing against different Rails versions (e.g. RAILS_VERSION=7.1).
# Unset, the newest supported Rails that runs on the current Ruby is used:
# Rails 8.x needs Ruby 3.2+, so Ruby 3.1 falls back to 7.2.
rails_version = ENV['RAILS_VERSION'] || (RUBY_VERSION >= '3.2' ? '8.1' : '7.2')
gem 'rails', "~> #{rails_version}"

# Allow testing against different Faraday versions (e.g. FARADAY_VERSION=1.10).
# Unset, the gemspec constraint picks the latest release.
faraday_version = ENV['FARADAY_VERSION']
gem 'faraday', "~> #{faraday_version}" if faraday_version

gem 'byebug'
gem 'mysql2'
gem 'pry-byebug'
gem 'rake', '~> 13.0'
