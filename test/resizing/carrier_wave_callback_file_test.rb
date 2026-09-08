# frozen_string_literal: true

require 'test_helper'

module Resizing
  # :cache コールバックに渡されるファイル (CallbackFile) の拡張子が content_type から決まることをテストする
  class CarrierWaveCallbackFileTest < Minitest::Test
    # Resizing の公開 URL の最後のセグメント (バージョン文字列)。ドットを含むので
    # ファイル名としては `Fv_Q` が拡張子に見える
    RESIZING_FILENAME = 'v0cRq7Yb2mZt9LxA3wN8eKd5pHs1.Fv_Q'

    def test_original_filename_is_nil_when_the_file_has_no_name
      file = Resizing::CarrierWave::CallbackFile.new(StringIO.new('data'))

      assert_nil file.original_filename
      assert_nil file.extension
    end

    def test_extension_follows_the_content_type
      file = build_file(RESIZING_FILENAME, 'image/jpeg')

      assert_equal 'v0cRq7Yb2mZt9LxA3wN8eKd5pHs1.jpeg', file.original_filename
      assert_equal 'jpeg', file.extension
    end

    def test_file_name_is_kept_when_its_extension_belongs_to_the_content_type
      # jpg は image/jpeg の拡張子の一つなので、jpeg に付け替えられない (大文字小文字も区別しない)
      file = build_file('photo.JPG', 'image/jpeg')

      assert_equal 'photo.JPG', file.original_filename
      assert_equal 'JPG', file.extension
    end

    def test_file_name_is_kept_when_the_content_type_is_not_registered
      file = build_file('photo.jpg', 'image/x-unregistered-type')

      assert_equal 'photo.jpg', file.original_filename
    end

    def test_mini_mime_is_used_when_mime_types_is_not_loaded
      file = build_file(RESIZING_FILENAME, 'image/jpeg')

      file.stub(:mime_types_available?, false) do
        assert_equal 'v0cRq7Yb2mZt9LxA3wN8eKd5pHs1.jpeg', file.original_filename
      end
    end

    def test_file_name_is_kept_when_mini_mime_does_not_know_the_content_type
      file = build_file('photo.jpg', 'image/x-unregistered-type')

      file.stub(:mime_types_available?, false) do
        assert_equal 'photo.jpg', file.original_filename
      end
    end

    def test_file_name_is_kept_when_no_lookup_library_is_loaded
      file = build_file(RESIZING_FILENAME, 'image/jpeg')

      file.stub(:mime_types_available?, false) do
        file.stub(:mini_mime_available?, false) do
          assert_equal RESIZING_FILENAME, file.original_filename
        end
      end
    end

    private

    def build_file(filename, content_type)
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        filename: filename,
        type: content_type,
        tempfile: File.open('test/data/images/sample1.jpg', 'r')
      )
      Resizing::CarrierWave::CallbackFile.new(uploaded_file)
    end
  end
end
