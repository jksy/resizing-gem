# frozen_string_literal: true
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  add_filter "/test/"

  if ENV['CI']
    formatter SimpleCov::Formatter::CoberturaFormatter
  else
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::SimpleFormatter,
                                                         SimpleCov::Formatter::HTMLFormatter
                                                       ])
  end

  enable_coverage :branch
  primary_coverage :branch
end

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

  # raise Faraday::TimeoutError, when project_id is timeout_project_id
  c.before_http_request(lambda {|r| URI(r.uri).path.match? %r(/projects/timeout_project_id) } ) do
    raise Faraday::TimeoutError
  end
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

  %i(test_models test_jpg_models test_model_with_default_urls).each do |model_name|
    connection.execute "drop table if exists #{model_name}"

    create_table model_name do |t|
      t.string :resizing_picture, null: true, default: nil
    end
  end
end

class ResizingUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  version :small do
    process resize_to_fill: [40, 40]
  end

  process resize_to_limit: [1000]
end

class ResizingJPGUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  process resize_to_limit: [1000]

  # override Resizing::CarrierWave#default_format
  def default_format
    'jpg'
  end

  def default_url
    'http://example.com/test.jpg'
  end
end

class ResizingUploaderWithDefaultURL < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  process resize_to_limit: [1000]

  def default_url
    'http://example.com/test.jpg'
  end
end

class TestModel < ::ActiveRecord::Base
  extend CarrierWave::Mount

  mount_uploader :resizing_picture, ResizingUploader
end

class TestJPGModel < ::ActiveRecord::Base
  extend CarrierWave::Mount

  mount_uploader :resizing_picture, ResizingJPGUploader
end

class TestModelWithDefaultURL < ::ActiveRecord::Base
  extend CarrierWave::Mount

  mount_uploader :resizing_picture, ResizingUploaderWithDefaultURL
end
