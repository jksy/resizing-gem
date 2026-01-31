# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in resizing.gemspec
gemspec

# Allow testing against different Rails versions
rails_version = ENV['RAILS_VERSION'] || '7.0'
gem 'rails', "~> #{rails_version}"

# Allow testing against different Faraday versions
faraday_version = ENV['FARADAY_VERSION'] || '2.0'
gem 'faraday', "~> #{faraday_version}"

gem 'byebug'
gem 'github_changelog_generator'
gem 'mysql2'
gem 'pry-byebug'
gem 'rake', '~> 13.0'
