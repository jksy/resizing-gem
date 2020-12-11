# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'github_changelog_generator/task'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'jksy'
  config.project = 'resizing-gem'
  config.since_tag = 'v0.1.0'
  config.future_release = Resizing::VERSION
end

task default: :test
