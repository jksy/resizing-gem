$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'resizing'
require 'time'
require 'timecop'
require 'vcr'

require 'minitest/autorun'

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr'
  c.hook_into :faraday
  c.allow_http_connections_when_no_cassette = false
end
