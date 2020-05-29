$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'resizing'
require 'rails'
require 'active_record'
require 'time'
require 'timecop'
require 'vcr'
require 'carrierwave'

require 'minitest/autorun'

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr'
  c.hook_into :faraday
  c.allow_http_connections_when_no_cassette = false
end
