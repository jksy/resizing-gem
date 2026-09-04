# frozen_string_literal: true

require 'test_helper'

module Resizing
  # Resizing::CarrierWave#cache! が CarrierWave の :cache コールバックを通すことをテストする
  #
  # - before :cache のチェック (拡張子 / content_type / サイズ) はアップロード前に働く
  # - process! と cache_versions! は Resizing の設計に合わないので発火しない
  class CarrierWaveCacheCallbacksTest < Minitest::Test
    include VCRRequestAssertions
    include ResizingTestConfiguration

    def setup
      TestModel.delete_all
      configure_resizing
    end

    def teardown; end

    # ============================================================
    # before :cache のチェックが働くこと (アップロードされない)
    # ============================================================

    def test_extension_allowlist_rejects_file_without_uploading
      assert_rejected_before_upload TestModelWithExtensionAllowlist
    end

    def test_extension_denylist_rejects_file_without_uploading
      assert_rejected_before_upload TestModelWithExtensionDenylist
    end

    def test_content_type_allowlist_rejects_file_without_uploading
      assert_rejected_before_upload TestModelWithContentTypeAllowlist
    end

    def test_size_range_rejects_file_without_uploading
      assert_rejected_before_upload TestModelWithSizeRange
    end

    def test_cache_raises_integrity_error_when_called_directly
      model = TestModelWithExtensionAllowlist.new
      uploader = ResizingUploaderWithExtensionAllowlist.new(model, :resizing_picture)

      assert_vcr_no_requests 'carrier_wave_test/save' do
        assert_raises(::CarrierWave::IntegrityError) { uploader.cache!(sample_uploaded_file) }
      end

      assert_nil model.read_attribute(:resizing_picture)
    end

    def test_cache_ignores_empty_file
      # 中身のないファイルは CarrierWave 本体の cache! と同じくアップロードしない
      model = TestModel.new
      uploader = ResizingUploader.new(model, :resizing_picture)

      assert_vcr_no_requests 'carrier_wave_test/save' do
        assert_nil uploader.cache!(StringIO.new(''))
      end

      assert_nil model.read_attribute(:resizing_picture)
    end

    # ============================================================
    # Resizing の設計に合わないコールバックが発火しないこと
    # ============================================================

    def test_versions_are_not_uploaded_again
      # ResizingUploader は version :small を持つが、version は配信時に変換されるので
      # cache_versions! による追加アップロードは発生しない
      model = TestModel.new

      assert_vcr_requests_count 'carrier_wave_test/save', 1 do
        model.resizing_picture = sample_uploaded_file
      end

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_processors_are_not_executed_on_upload
      # process は配信 URL の transform 定義なので、uploader のメソッドとしては存在しない。
      # process! が発火すると NoMethodError になる
      model = TestModelWithUndefinedProcessor.new

      assert_vcr_requests_count 'carrier_wave_test/save', 1 do
        model.resizing_picture = sample_uploaded_file
      end

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    private

    # 画像の代入時に POST が発行されず、モデルが integrity error で invalid になることを確認する
    def assert_rejected_before_upload(model_class)
      model = model_class.new

      assert_vcr_no_requests 'carrier_wave_test/save' do
        model.resizing_picture = sample_uploaded_file
      end

      refute model.valid?, "#{model_class} should be invalid after the file was rejected"
      refute_empty model.errors[:resizing_picture]
      assert_nil model.read_attribute(:resizing_picture)
    end
  end
end
