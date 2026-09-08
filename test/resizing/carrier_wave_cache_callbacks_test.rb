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
    # 拡張子のチェックが content_type から判定されること
    # ============================================================

    # Resizing の公開 URL は末尾がバージョン文字列 (`/v<version>`) で、ドットを含むため
    # ファイル名から取れる「拡張子」はバージョンの一部 (`Fv_Q`) になる
    # (ダウンロードは差し替えるので、URL の中身は実在しなくてよい)
    RESIZING_IMAGE_URL = "#{ResizingTestConfiguration::CONFIGURATION_TEMPLATE[:image_host]}" \
                         "/projects/#{ResizingTestConfiguration::CONFIGURATION_TEMPLATE[:project_id]}" \
                         '/upload/images/3f2c9d1e-5b7a-4e8c-9a0d-6c1b2e3f4a5d/v0cRq7Yb2mZt9LxA3wN8eKd5pHs1.Fv_Q'.freeze

    def test_remote_resizing_url_is_accepted_by_content_type
      # `remote_<column>_url=` に Resizing の URL を渡した場合、ファイル名の拡張子 (Fv_Q) ではなく
      # レスポンスの Content-Type (image/jpeg) で判定され、アップロードされる
      model = TestModelWithJpegAllowlist.new
      remote_file = sample_remote_file(RESIZING_IMAGE_URL, content_type: 'image/jpeg')

      assert_vcr_requests_count 'carrier_wave_test/save', 1 do
        with_stubbed_download(remote_file) do
          model.remote_resizing_picture_url = RESIZING_IMAGE_URL
        end
      end

      assert model.valid?, model.errors.full_messages.join(', ')
      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_remote_file_is_rejected_when_content_type_is_not_allowed
      # Content-Type が image/png なら、拡張子の許可リスト (jpg / jpeg) に合わないので拒否される
      model = TestModelWithJpegAllowlist.new
      remote_file = sample_remote_file(RESIZING_IMAGE_URL, content_type: 'image/png')

      assert_vcr_no_requests 'carrier_wave_test/save' do
        with_stubbed_download(remote_file) do
          model.remote_resizing_picture_url = RESIZING_IMAGE_URL
        end
      end

      refute model.valid?
      refute_empty model.errors[:resizing_picture]
      assert_nil model.read_attribute(:resizing_picture)
    end

    def test_extension_of_file_name_is_used_when_content_type_is_unknown
      # application/octet-stream は型の情報を持たないので、ファイル名の拡張子 (jpg) で判定される
      model = TestModelWithJpegAllowlist.new
      url = 'https://example.com/images/photo.jpg'
      remote_file = sample_remote_file(url, content_type: 'application/octet-stream')

      assert_vcr_requests_count 'carrier_wave_test/save', 1 do
        with_stubbed_download(remote_file) do
          model.remote_resizing_picture_url = url
        end
      end

      assert model.valid?, model.errors.full_messages.join(', ')
      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_extension_of_file_name_is_used_when_content_type_is_not_registered
      # MIME::Types / MiniMime に登録されていない content_type でもエラーにならず、
      # ファイル名の拡張子 (jpg) で判定される
      model = TestModelWithJpegAllowlist.new
      url = 'https://example.com/images/photo.jpg'
      remote_file = sample_remote_file(url, content_type: 'image/x-unregistered-type')

      assert_vcr_requests_count 'carrier_wave_test/save', 1 do
        with_stubbed_download(remote_file) do
          model.remote_resizing_picture_url = url
        end
      end

      assert model.valid?, model.errors.full_messages.join(', ')
      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_content_type_parameters_are_ignored
      # `image/jpeg; charset=binary` のようなパラメータ付きの値でも image/jpeg として判定される
      model = TestModelWithJpegAllowlist.new
      remote_file = sample_remote_file(RESIZING_IMAGE_URL, content_type: 'image/jpeg; charset=binary')

      assert_vcr_requests_count 'carrier_wave_test/save', 1 do
        with_stubbed_download(remote_file) do
          model.remote_resizing_picture_url = RESIZING_IMAGE_URL
        end
      end

      assert model.valid?, model.errors.full_messages.join(', ')
      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_content_type_takes_precedence_over_extension_of_uploaded_file
      # ローカルからのアップロードでも、ファイル名の拡張子 (jpg) より content_type (image/png) が優先される
      model = TestModelWithJpegAllowlist.new
      file = File.open('test/data/images/sample1.jpg', 'r')
      uploaded_file = ActionDispatch::Http::UploadedFile.new(filename: 'sample1.jpg', type: 'image/png', tempfile: file)

      assert_vcr_no_requests 'carrier_wave_test/save' do
        model.resizing_picture = uploaded_file
      end

      refute model.valid?
      assert_nil model.read_attribute(:resizing_picture)
    end

    def test_uploaded_file_matching_its_content_type_is_accepted
      # 拡張子と content_type が一致する通常のアップロードは、これまで通り受け付けられる
      model = TestModelWithJpegAllowlist.new

      assert_vcr_requests_count 'carrier_wave_test/save', 1 do
        model.resizing_picture = sample_uploaded_file
      end

      assert model.valid?, model.errors.full_messages.join(', ')
      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
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
