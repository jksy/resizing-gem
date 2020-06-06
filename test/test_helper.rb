$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'time'
require 'timecop'
require 'vcr'

require 'rails'
require 'active_record'
require 'fog-aws'
require 'carrierwave'
require 'resizing'
require 'pry-byebug'

require 'minitest/autorun'

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr'
  c.hook_into :faraday
  c.allow_http_connections_when_no_cassette = false
end

ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: '127.0.0.1',
  port: 3306,
  database: 'resizing_gem_test',
  encoding: 'utf8',
  username: 'root',
  password: 'secret'
)

ActiveRecord::Schema.define do
  self.verbose = false
  connection.execute 'drop table if exists test_models'

  create_table :test_models do |t|
    t.string :resizing_picture, null: true, default: nil
  end
end

class ResizingUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  process resize_to_limit: [1000]
end

class TestModel < ::ActiveRecord::Base
  extend CarrierWave::Mount

  mount_uploader :resizing_picture, ResizingUploader
end
