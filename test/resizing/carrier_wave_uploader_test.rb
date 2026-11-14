# frozen_string_literal: true

require 'test_helper'

module Resizing
  # Resizing::CarrierWave を include したアップローダ単体の挙動をテストする
  # (モデルの保存・削除を伴う結合テストは carrier_wave_test.rb を参照)
  class CarrierWaveUploaderTest < Minitest::Test
    include VCRRequestAssertions
    include ResizingTestConfiguration

    IDENTIFIER = ResizingTestConfiguration::UPLOADED_IDENTIFIER

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

    class ConditionalProcessUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave

      process resize_to_fill: [10, 10], if: :always?
      process resize_to_fill: [20, 20], if: :never?
      process resize_to_fill: [30, 30], if: ->(uploader, options) { uploader.always?(options[:file]) }
      process resize_to_fill: [40, 40], if: ->(uploader, options) { uploader.never?(options[:file]) }

      def always?(_file)
        true
      end

      def never?(_file)
        false
      end
    end

    class VersionedUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave

      version :large do
        process resize_to_fill: [400, 400]

        version :thumb do
          process resize_to_fill: [40, 40]
        end
      end

      def default_url(*_args)
        "/images/fallback/#{[version_name, 'default.png'].compact.join('_')}"
      end
    end

    class PlainUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave
    end

    class VersionedModel < ::ActiveRecord::Base
      self.table_name = 'test_models'

      mount_uploader :resizing_picture, VersionedUploader
    end

    class ConditionalProcessModel < ::ActiveRecord::Base
      self.table_name = 'test_models'

      mount_uploader :resizing_picture, ConditionalProcessUploader
    end

    class PlainModel < ::ActiveRecord::Base
      self.table_name = 'test_models'

      mount_uploader :resizing_picture, PlainUploader
    end

    class NoProcessorUploader < ::CarrierWave::Uploader::Base
      include Resizing::CarrierWave
    end

    def setup
      configure_resizing
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

    def test_transform_string_skips_processes_whose_condition_is_false
      uploader = model_with_image(ConditionalProcessModel).resizing_picture

      assert_equal 'c_fill,w_10,h_10/c_fill,w_30,h_30', uploader.transform_string
    end

    def test_process_with_unless_condition_is_skipped_when_condition_is_true
      # CarrierWave 2.x の process は unless: に対応していないので、条件の評価だけを確かめる
      uploader = model_with_image(ConditionalProcessModel).resizing_picture

      assert uploader.send(:process_applicable?, :resize_to_fill, [10, 10], :never?, :unless)
      refute uploader.send(:process_applicable?, :resize_to_fill, [10, 10], :always?, :unless)
      refute uploader.send(:process_applicable?, :resize_to_fill, [10, 10], ->(*) { true }, :unless)
    end

    def test_transform_path_of_version_starts_with_parent_transforms
      uploader = TestModel.new.resizing_picture

      assert_equal 'c_limit,w_1000', uploader.transform_path
      assert_equal 'c_limit,w_1000/c_fill,w_40,h_40', uploader.small.transform_path
    end

    # ============================================================
    # url
    # ============================================================

    def test_url_is_built_from_configured_image_host_and_column_value
      model = model_with_image

      assert_equal "http://192.168.56.101:5000#{IDENTIFIER}/c_limit,w_1000", model.resizing_picture.url

      # image_host を差し替えると URL も追従する (保存済みカラム値にはホストを含まない)
      configure_resizing(image_host: 'https://cdn.example.com')
      assert_equal "https://cdn.example.com#{IDENTIFIER}/c_limit,w_1000", model.resizing_picture.url
    end

    def test_url_ends_with_slash_without_processors
      model = model_with_image(PlainModel)

      assert_equal "http://192.168.56.101:5000#{IDENTIFIER}/", model.resizing_picture.url
    end

    def test_url_with_version_appends_transform_string_after_parent
      model = model_with_image

      assert_equal "http://192.168.56.101:5000#{IDENTIFIER}/c_limit,w_1000/c_fill,w_40,h_40",
                   model.resizing_picture.url(:small)
    end

    def test_version_uploader_url_matches_url_with_version
      # CarrierWave の書き方 (version uploader の url) でも変換が付く
      model = model_with_image

      assert_equal model.resizing_picture.url(:small), model.resizing_picture.small.url
      assert_equal model.resizing_picture.url(:small), model.resizing_picture.versions[:small].url
    end

    def test_url_with_nested_version
      model = model_with_image(VersionedModel)

      assert_equal "http://192.168.56.101:5000#{IDENTIFIER}/c_fill,w_400,h_400/c_fill,w_40,h_40",
                   model.resizing_picture.url(:large, :thumb)
      assert_equal model.resizing_picture.url(:large, :thumb), model.resizing_picture.large.thumb.url
    end

    def test_serializable_hash_has_url_of_each_version
      model = model_with_image

      assert_equal(
        {
          'url' => "http://192.168.56.101:5000#{IDENTIFIER}/c_limit,w_1000",
          'small' => { 'url' => "http://192.168.56.101:5000#{IDENTIFIER}/c_limit,w_1000/c_fill,w_40,h_40" }
        },
        model.resizing_picture.serializable_hash
      )
    end

    def test_url_accepts_string_version_name
      model = model_with_image

      assert_equal model.resizing_picture.url(:small), model.resizing_picture.url('small')
    end

    def test_url_raises_for_unknown_version
      model = model_with_image

      error = assert_raises(ArgumentError) { model.resizing_picture.url(:nope) }
      assert_includes error.message, 'nope'
    end

    def test_url_returns_default_url_when_column_is_blank
      assert_nil TestModel.new.resizing_picture.url
      assert_equal 'http://example.com/test.jpg', TestModelWithDefaultURL.new.resizing_picture.url
    end

    def test_url_with_version_returns_default_url_of_the_version_when_column_is_blank
      model = VersionedModel.new

      assert_equal '/images/fallback/default.png', model.resizing_picture.url
      assert_equal '/images/fallback/large_default.png', model.resizing_picture.url(:large)
      assert_equal '/images/fallback/large_thumb_default.png', model.resizing_picture.url(:large, :thumb)
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
      assert_nil uploader.retrieve_versions_from_cache!(IDENTIFIER)
    end

    def test_cache_expires_in_defaults_to_nil
      assert_nil TestModel.new.resizing_picture.cache_expires_in
    end

    def test_cached_file_is_not_deleted_after_storing
      # 一時画像は確定するとそのまま保存済みの画像になるので、保存後に削除してはいけない
      assert_equal false, TestModel.new.resizing_picture.delete_tmp_file_after_storage
    end

    def test_cache_name_is_nil_when_nothing_is_cached
      assert_nil TestModel.new.resizing_picture.cache_name
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
