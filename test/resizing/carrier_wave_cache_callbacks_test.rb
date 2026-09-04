# frozen_string_literal: true

require 'test_helper'

module Resizing
  # Resizing::CarrierWave#cache! が CarrierWave の :cache コールバックを通すことをテストする
  #
  # - before :cache のチェック (拡張子 / content_type / サイズ) はアップロード前に働く
  # - process! と cache_versions! は Resizing の設計に合わないので発火しない
  class CarrierWaveCacheCallbacksTest < Minitest::Test
    include VCRRequestAssertions

    def setup
      TestModel.delete_all

      Resizing.configure = {
        image_host: 'http://192.168.56.101:5000',
        project_id: 'e06e710d-f026-4dcf-b2c0-eab0de8bb83f',
        secret_token: 'ewbym2r1pk49x1d2lxdbiiavnqp25j2kh00hsg3koy0ppm620x5mhlmgl3rq5ci8',
        open_timeout: 10,
        response_timeout: 20
      }
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

    def sample_uploaded_file
      file = File.open('test/data/images/sample1.jpg', 'r')
      ActionDispatch::Http::UploadedFile.new(
        filename: File.basename(file.path),
        type: 'image/jpeg',
        tempfile: file
      )
    end

    def expect_identifier
      '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
    end
  end
end
