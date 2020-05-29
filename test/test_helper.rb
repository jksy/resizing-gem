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

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :test_models do |t|
    t.string  :resizing_picture
  end
end

class ResizingUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave
end

class TestModel < ::ActiveRecord::Base
  extend CarrierWave::Mount

  mount_uploader :resizing_picture, ResizingUploader
end
