# frozen_string_literal: true

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  add_filter '/test/'

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
require 'logger'

require 'rails'
require 'active_record'
require 'fog-aws'
require 'carrierwave'
require 'carrierwave/orm/activerecord'
require 'resizing'
require 'pry-byebug'

require 'minitest/autorun'
require 'minitest/mock'

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr'
  c.hook_into :faraday
  c.allow_http_connections_when_no_cassette = false

  # raise Faraday::TimeoutError, when project_id is timeout_project_id
  c.before_http_request(->(r) { URI(r.uri).path.match? %r{/projects/timeout_project_id} }) do
    raise Faraday::TimeoutError
  end
end

# VCRカセットのリクエストが実際に使用されたかを検証するヘルパー
module VCRRequestAssertions
  # VCRカセット内でブロックを実行し、カセットのインタラクションがすべて使用されたことを確認
  #
  # @param cassette_name [String] VCRカセット名
  # @param options [Hash] VCR.use_cassetteに渡すオプション
  # @yield 実行するブロック
  # @return [void]
  #
  # @example
  #   assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
  #     model.remove_resizing_picture!
  #     model.save!
  #   end
  def assert_vcr_requests_made(cassette_name, options = {})
    options = { record: :none }.merge(options)

    VCR.use_cassette(cassette_name, options) do |cassette|
      interaction_list = cassette.http_interactions
      initial_count = interaction_list.remaining_unused_interaction_count

      assert initial_count.positive?,
             "Cassette '#{cassette_name}' should have at least 1 interaction"

      yield cassette if block_given?

      remaining_count = interaction_list.remaining_unused_interaction_count
      used_count = initial_count - remaining_count

      assert_equal 0, remaining_count,
                   "Expected all #{initial_count} cassette interactions to be used, " \
                   "but #{remaining_count} remain unused (#{used_count} were used)"
    end
  end

  # VCRカセット内でブロックを実行し、指定した数のインタラクションが使用されたことを確認
  #
  # @param cassette_name [String] VCRカセット名
  # @param expected_count [Integer] 使用されるべきインタラクション数
  # @param options [Hash] VCR.use_cassetteに渡すオプション
  # @yield 実行するブロック
  # @return [void]
  #
  # @example
  #   assert_vcr_requests_count 'client/post', 1 do
  #     Resizing.post(file)
  #   end
  def assert_vcr_requests_count(cassette_name, expected_count, options = {})
    options = { record: :none }.merge(options)

    VCR.use_cassette(cassette_name, options) do |cassette|
      interaction_list = cassette.http_interactions
      initial_count = interaction_list.remaining_unused_interaction_count

      yield cassette if block_given?

      remaining_count = interaction_list.remaining_unused_interaction_count
      used_count = initial_count - remaining_count

      assert_equal expected_count, used_count,
                   "Expected #{expected_count} cassette interactions to be used, " \
                   "but #{used_count} were used"
    end
  end

  # VCRカセット内でブロックを実行し、リクエストが発行されないことを確認
  #
  # @param cassette_name [String] VCRカセット名
  # @param options [Hash] VCR.use_cassetteに渡すオプション
  # @yield 実行するブロック
  # @return [void]
  #
  # @example
  #   assert_vcr_no_requests 'carrier_wave_test/remove_resizing_picture' do
  #     model.remove_resizing_picture = true
  #     # save!を呼ばないのでリクエストは発行されない
  #   end
  def assert_vcr_no_requests(cassette_name, options = {}, &block)
    assert_vcr_requests_count(cassette_name, 0, options, &block)
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

  %i[test_models test_jpg_models test_model_with_default_urls].each do |model_name|
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
  mount_uploader :resizing_picture, ResizingUploader
end

class TestJPGModel < ::ActiveRecord::Base
  mount_uploader :resizing_picture, ResizingJPGUploader
end

class TestModelWithDefaultURL < ::ActiveRecord::Base
  mount_uploader :resizing_picture, ResizingUploaderWithDefaultURL
end

# コールバックのテスト用モデル
# mount_uploader が登録する各種コールバックが正しく動作するかをテストするため
# カスタムコールバックを追加して呼び出しを追跡する
class TestModelWithCallbackTracking < ::ActiveRecord::Base
  self.table_name = 'test_models'

  mount_uploader :resizing_picture, ResizingUploader

  attr_accessor :callback_log

  # before_save / after_save コールバック
  before_save :track_before_save
  after_save :track_after_save

  # before_destroy / after_destroy コールバック
  before_destroy :track_before_destroy
  after_destroy :track_after_destroy

  # after_commit コールバック
  after_commit :track_create_commit, on: :create
  after_commit :track_update_commit, on: :update
  after_commit :track_destroy_commit, on: :destroy

  def initialize(*args)
    super
    @callback_log = []
  end

  private

  def track_before_save
    @callback_log << :before_save
  end

  def track_after_save
    @callback_log << :after_save
  end

  def track_before_destroy
    @callback_log << :before_destroy
  end

  def track_after_destroy
    @callback_log << :after_destroy
  end

  def track_create_commit
    @callback_log << :create_commit
  end

  def track_update_commit
    @callback_log << :update_commit
  end

  def track_destroy_commit
    @callback_log << :destroy_commit
  end
end
