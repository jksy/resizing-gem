# frozen_string_literal: true

require 'test_helper'

module Resizing
  # Resizing::CarrierWave を include したアップローダ単体の挙動をテストする
  # (モデルの保存・削除を伴う結合テストは carrier_wave_test.rb を参照)
  class CarrierWaveUploaderTest < Minitest::Test
    include VCRRequestAssertions

    IDENTIFIER = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'

    class TransformationUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave

      process resize_to_fit: [100, 200]
      process transformation: { quality: 80, fetch_format: 'webp' }
    end

    class FormatOverridesFetchFormatUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave

      process transformation: { fetch_format: 'webp', format: 'png' }
    end

    class UnsupportedProcessorUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave

      process convert: 'png'
    end

    class NoProcessorUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave
    end

    def setup
      @configuration_template = {
        image_host: 'http://192.168.56.101:5000',
        video_host: 'http://192.168.56.101:5000',
        project_id: 'e06e710d-f026-4dcf-b2c0-eab0de8bb83f',
        secret_token: 'ewbym2r1pk49x1d2lxdbiiavnqp25j2kh00hsg3koy0ppm620x5mhlmgl3rq5ci8'
      }
      Resizing.configure = @configuration_template
    end

    def teardown
      # NOP
    end

    def model_with_image(model_class = TestModel, identifier = IDENTIFIER)
      model = model_class.new
      model.send(:write_attribute, :resizing_picture, identifier)
      model
    end

    # ============================================================
    # include 時の設定
    # ============================================================

    def test_including_module_sets_remote_storage
      assert_equal Resizing::CarrierWave::Storage::Remote, NoProcessorUploader.storage
      assert_instance_of Resizing::CarrierWave::Storage::Remote, NoProcessorUploader.new.send(:storage)
    end

    def test_railtie_is_defined
      assert Resizing::CarrierWave::Railtie < ::Rails::Railtie
    end

    # ============================================================
    # transform_string
    # ============================================================

    def test_transform_string_for_resize_to_limit_without_height
      assert_equal 'c_limit,w_1000', ResizingUploader.new.transform_string
    end

    def test_transform_string_for_version_with_resize_to_fill
      assert_equal 'c_fill,w_40,h_40', TestModel.new.resizing_picture.versions[:small].transform_string
    end

    def test_transform_string_joins_multiple_processors_with_slash
      assert_equal 'c_fit,w_100,h_200/q_80,f_webp', TransformationUploader.new.transform_string
    end

    def test_transform_string_format_takes_precedence_over_fetch_format
      assert_equal 'f_png', FormatOverridesFetchFormatUploader.new.transform_string
    end

    def test_transform_string_is_empty_without_processors
      assert_equal '', NoProcessorUploader.new.transform_string
    end

    def test_transform_string_raises_for_unsupported_processor
      error = assert_raises(NotImplementedError) { UnsupportedProcessorUploader.new.transform_string }
      assert_includes error.message, 'convert'
    end

    # ============================================================
    # url
    # ============================================================

    def test_url_is_built_from_configured_image_host_and_column_value
      model = model_with_image

      assert_equal "http://192.168.56.101:5000#{IDENTIFIER}/", model.resizing_picture.url

      # image_host を差し替えると URL も追従する (保存済みカラム値にはホストを含まない)
      Resizing.configure = @configuration_template.merge(image_host: 'https://cdn.example.com')
      assert_equal "https://cdn.example.com#{IDENTIFIER}/", model.resizing_picture.url
    end

    def test_url_with_version_appends_transform_string
      model = model_with_image

      assert_equal "http://192.168.56.101:5000#{IDENTIFIER}/c_fill,w_40,h_40", model.resizing_picture.url(:small)
    end

    def test_url_accepts_string_version_name
      model = model_with_image

      assert_equal model.resizing_picture.url(:small), model.resizing_picture.url('small')
    end

    def test_url_raises_for_unknown_version
      model = model_with_image

      error = assert_raises(RuntimeError) { model.resizing_picture.url(:nope) }
      assert_includes error.message, 'nope'
      assert_includes error.message, 'small'
    end

    def test_url_returns_default_url_when_column_is_blank
      assert_nil TestModel.new.resizing_picture.url
      assert_equal 'http://example.com/test.jpg', TestModelWithDefaultURL.new.resizing_picture.url
    end

    def test_url_ignores_version_when_column_is_blank
      # カラムが空なら version 指定があっても default_url を返す
      assert_nil TestModel.new.resizing_picture.url(:small)
    end

    def test_model_url_helper_delegates_to_uploader_url
      model = model_with_image

      assert_equal model.resizing_picture.url, model.resizing_picture_url
      assert_equal model.resizing_picture.url(:small), model.resizing_picture_url(:small)
    end

    # ============================================================
    # identifier / filename / file
    # ============================================================

    def test_filename_and_identifier_return_column_value
      model = model_with_image

      assert_equal IDENTIFIER, model.resizing_picture.filename
      assert_equal IDENTIFIER, model.resizing_picture.identifier
    end

    def test_file_reflects_column_value
      model = model_with_image
      file = model.resizing_picture.file

      assert_instance_of Resizing::CarrierWave::Storage::File, file
      assert_equal IDENTIFIER, file.public_id.to_s
      assert_equal IDENTIFIER, file.path
    end

    def test_uploader_is_present_when_column_has_value
      model = model_with_image

      assert model.resizing_picture.present?
      refute model.resizing_picture.blank?
    end

    # ============================================================
    # cache! / store_versions! / remove_versions! / rename
    # ============================================================

    def test_cache_with_nil_does_nothing
      uploader = TestModel.new.resizing_picture

      assert_vcr_no_requests 'carrier_wave_test/save' do
        assert_nil uploader.cache!(nil)
      end
      assert_nil uploader.file
    end

    def test_store_versions_and_remove_versions_are_noop
      uploader = TestModel.new.resizing_picture

      assert_nil uploader.store_versions!
      assert_nil uploader.remove_versions!
    end

    def test_rename_raises_not_implemented_error
      assert_raises(NotImplementedError) { TestModel.new.resizing_picture.rename }
    end

    # ============================================================
    # format
    # ============================================================

    def test_format_related_methods_default_to_nil
      uploader = TestModel.new.resizing_picture

      assert_nil uploader.requested_format
      assert_nil uploader.default_format
      assert_nil uploader.format
    end

    def test_format_uses_overridden_default_format
      assert_equal 'jpg', TestJPGModel.new.resizing_picture.format
    end
  end
end
