# frozen_string_literal: true

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  add_filter '/test/'
  # bundle install で vendor/ 配下に入る gem を計測対象から除外し、
  # カバレッジ率が lib の実態を表すようにする
  add_filter '/vendor/'
  track_files 'lib/**/*.rb'

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
require 'digest'
require 'socket'
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

# Resizing::Client の代わりに使う偽クライアント (delete の応答を固定し、呼び出しを記録する)
class FakeApiClient
  attr_reader :deleted_ids

  def initialize(response)
    @response = response
    @deleted_ids = []
  end

  def delete(image_id)
    @deleted_ids << image_id
    @response.dup
  end
end

# Resizing::Client を FakeApiClient に差し替えるヘルパー
module FakeApiClientAssertions
  # Resizing::Client.new が FakeApiClient を返す状態でブロックを実行する
  #
  # @param response [Hash] 偽クライアントの delete が返す固定レスポンス
  # @yield [FakeApiClient] 差し替えた偽クライアント
  # @return [Object] ブロックの戻り値
  #
  # @example
  #   with_fake_api_client({ 'id' => IMAGE_ID }) do |fake|
  #     file.delete
  #     assert_equal [IMAGE_ID], fake.deleted_ids
  #   end
  def with_fake_api_client(response)
    fake = FakeApiClient.new(response)
    Resizing::Client.stub(:new, fake) { yield fake }
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

# Test database setup
#
# By default each test process creates its own database and drops it when the
# run finishes, so that several test processes sharing one MySQL server do not
# overwrite each other's tables and records.
#
# The server can be overridden with MYSQL_HOST / MYSQL_PORT / MYSQL_USER /
# MYSQL_PASSWORD (the dev container runs MySQL in a separate container).
# Setting MYSQL_DATABASE uses that database as is and never drops it; give each
# concurrent process a different name in that case.
module TestDatabase
  BASE_NAME = 'resizing_gem_test'

  module_function

  # Host identifier mixed into the per-process database name, so that PIDs from
  # different hosts do not collide on a shared MySQL server
  def host_token
    @host_token ||= Digest::MD5.hexdigest(Socket.gethostname)[0, 8]
  end

  def per_process_name_pattern
    /\A#{Regexp.escape(BASE_NAME)}_#{host_token}_(\d+)\z/
  end

  def database_name
    @database_name ||= ENV['MYSQL_DATABASE'] || "#{BASE_NAME}_#{host_token}_#{Process.pid}"
  end

  # Whether the database belongs to this process alone and can be dropped
  def ephemeral?
    ENV['MYSQL_DATABASE'].nil?
  end

  def server_config
    {
      adapter: 'mysql2',
      host: ENV.fetch('MYSQL_HOST', '127.0.0.1'),
      port: Integer(ENV.fetch('MYSQL_PORT', '3306')),
      encoding: 'utf8',
      username: ENV.fetch('MYSQL_USER', 'root'),
      password: ENV.fetch('MYSQL_PASSWORD', 'secret')
    }
  end

  def setup
    ActiveRecord::Base.establish_connection(server_config)
    drop_abandoned_databases if ephemeral?
    ActiveRecord::Base.connection.execute("create database if not exists `#{database_name}`")
    ActiveRecord::Base.establish_connection(server_config.merge(database: database_name))

    # Minitest.after_run, not at_exit: at_exit handlers run in reverse order of
    # registration, so this one would drop the database before the tests run
    Minitest.after_run { drop_database } if ephemeral?
  end

  def drop_database
    ActiveRecord::Base.establish_connection(server_config)
    ActiveRecord::Base.connection.execute("drop database if exists `#{database_name}`")
  rescue StandardError => e
    warn "failed to drop test database #{database_name}: #{e.message}"
  end

  # Clean up databases left behind by processes that were killed before they
  # could drop their own
  def drop_abandoned_databases
    connection = ActiveRecord::Base.connection

    connection.select_values('show databases').each do |database|
      matched = per_process_name_pattern.match(database)
      next if matched.nil? || process_alive?(matched[1].to_i)

      connection.execute("drop database if exists `#{database}`")
    end
  rescue StandardError => e
    warn "failed to drop abandoned test databases: #{e.message}"
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end
end

TestDatabase.setup

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

# before :cache コールバック (拡張子 / content_type / サイズのチェック) のテスト用アップローダ
class ResizingUploaderWithExtensionAllowlist < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  def extension_allowlist
    %w[png]
  end
end

class ResizingUploaderWithExtensionDenylist < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  def extension_denylist
    %w[jpg]
  end
end

class ResizingUploaderWithContentTypeAllowlist < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  def content_type_allowlist
    ['image/png']
  end
end

class ResizingUploaderWithSizeRange < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  def size_range
    0..10
  end
end

# process! が発火しないことのテスト用アップローダ
# convert / transformation は配信 URL の transform を組み立てるための宣言であり
# uploader のメソッドとしては存在しないので、process! が走ると NoMethodError になる
class ResizingUploaderWithUndefinedProcessor < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  process convert: 'png'
end

class TestModel < ::ActiveRecord::Base
  mount_uploader :resizing_picture, ResizingUploader
end

class TestModelWithExtensionAllowlist < ::ActiveRecord::Base
  self.table_name = 'test_models'

  mount_uploader :resizing_picture, ResizingUploaderWithExtensionAllowlist
end

class TestModelWithExtensionDenylist < ::ActiveRecord::Base
  self.table_name = 'test_models'

  mount_uploader :resizing_picture, ResizingUploaderWithExtensionDenylist
end

class TestModelWithContentTypeAllowlist < ::ActiveRecord::Base
  self.table_name = 'test_models'

  mount_uploader :resizing_picture, ResizingUploaderWithContentTypeAllowlist
end

class TestModelWithSizeRange < ::ActiveRecord::Base
  self.table_name = 'test_models'

  mount_uploader :resizing_picture, ResizingUploaderWithSizeRange
end

class TestModelWithUndefinedProcessor < ::ActiveRecord::Base
  self.table_name = 'test_models'

  mount_uploader :resizing_picture, ResizingUploaderWithUndefinedProcessor
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
