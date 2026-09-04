# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

module Resizing
  module CarrierWave
    module Storage
      class FileTest < Minitest::Test
        def setup
          @configuration_template = {
            image_host: 'http://192.168.56.101:5000',
            video_host: 'http://192.168.56.101:5000',
            project_id: 'e06e710d-f026-4dcf-b2c0-eab0de8bb83f',
            secret_token: 'ewbym2r1pk49x1d2lxdbiiavnqp25j2kh00hsg3koy0ppm620x5mhlmgl3rq5ci8',
            open_timeout: 10,
            response_timeout: 20
          }
          Resizing.configure = @configuration_template
        end

        def teardown
          # NOP
        end

        def test_initialize_without_identifier
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)

          assert_instance_of Resizing::CarrierWave::Storage::File, file
          assert file.public_id.empty?
        end

        def test_initialize_with_identifier
          model = TestModel.new
          uploader = model.resizing_picture
          identifier = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
          file = Resizing::CarrierWave::Storage::File.new(uploader, identifier)

          assert_instance_of Resizing::CarrierWave::Storage::File, file
          assert_equal identifier, file.public_id.to_s
        end

        def test_retrieve_sets_public_id
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)
          identifier = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'

          file.retrieve(identifier)

          assert_equal identifier, file.public_id.to_s
        end

        def test_delete_does_nothing_when_public_id_empty
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)

          # Should not raise any error and should return early
          result = file.delete
          assert_nil result
        end

        def test_current_path_returns_nil_for_new_model
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)

          assert_nil file.current_path
        end

        def test_path_alias
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)

          assert_nil file.current_path
          assert_nil file.path
        end

        def test_authenticated_url_returns_nil
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)

          assert_nil file.authenticated_url
        end

        def test_authenticated_url_with_options_returns_nil
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)

          assert_nil file.authenticated_url(expires_in: 3600)
        end

        def test_extension_raises_not_implemented_error
          model = TestModel.new
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader)

          assert_raises(NotImplementedError) do
            file.extension
          end
        end

        def test_name_returns_image_id_from_public_id
          model = TestModel.new
          identifier = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
          # Use write_attribute to set the column directly
          model.send(:write_attribute, :resizing_picture, identifier)
          uploader = model.resizing_picture
          file = Resizing::CarrierWave::Storage::File.new(uploader, identifier)

          # name returns image_id (UUID) from public_id
          assert_equal '14ea7aac-a194-4330-931f-6b562aec413d', file.name
        end

        def test_store_uploads_file_and_sets_public_id
          VCR.use_cassette 'carrier_wave_test/save', record: :once do
            model = TestModel.new
            uploader = model.resizing_picture
            file = Resizing::CarrierWave::Storage::File.new(uploader)

            source_file = ::File.open('test/data/images/sample1.jpg', 'r')
            uploaded_file = ActionDispatch::Http::UploadedFile.new(
              filename: ::File.basename(source_file.path),
              type: 'image/jpeg',
              tempfile: source_file
            )

            result = file.store(uploaded_file)

            assert result
            refute file.public_id.empty?
            assert_equal 'image/jpeg', file.content_type
          end
        end

        def test_store_with_file_object
          VCR.use_cassette 'carrier_wave_test/save', record: :once do
            model = TestModel.new
            uploader = model.resizing_picture
            file = Resizing::CarrierWave::Storage::File.new(uploader)

            source_file = ::File.open('test/data/images/sample1.jpg', 'r')

            result = file.store(source_file)

            assert result
            refute file.public_id.empty?
          end
        end

        def test_delete_with_valid_public_id
          VCR.use_cassette 'carrier_wave_test/remove_resizing_picture' do
            model = TestModel.new
            identifier = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
            model.send(:write_attribute, :resizing_picture, identifier)
            uploader = model.resizing_picture
            file = Resizing::CarrierWave::Storage::File.new(uploader, identifier)

            # This should call delete on Resizing API
            file.delete
          end
        end

        # ============================================================
        # delete の詳細な挙動 (Resizing::Client を偽クライアントに差し替えて検証)
        # ============================================================

        IDENTIFIER = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
        IMAGE_ID = '14ea7aac-a194-4330-931f-6b562aec413d'
        OTHER_IDENTIFIER = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/new-image-id-2222-2222-222222222222/v2'
        NOT_FOUND_RESPONSE = {
          'error' => 'ActiveRecord::RecordNotFound',
          'message' => "Upload::Image##{IMAGE_ID} not found(no record)"
        }.freeze

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

        def with_fake_api_client(response)
          fake = FakeApiClient.new(response)
          Resizing::Client.stub(:new, fake) { yield fake }
        end

        def model_with_column(value)
          model = TestModel.new
          model.send(:write_attribute, :resizing_picture, value)
          model
        end

        def test_delete_clears_column_when_deleted_image_is_current
          model = model_with_column(IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          with_fake_api_client({ 'id' => IMAGE_ID }) do |fake|
            file.delete
            assert_equal [IMAGE_ID], fake.deleted_ids
          end

          assert_nil model.read_attribute(:resizing_picture)
        end

        def test_delete_keeps_column_when_deleting_previous_image_after_update
          # 画像更新時: カラムは新しい画像を指しているが、削除対象は古い画像なのでカラムは消さない
          model = model_with_column(OTHER_IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          with_fake_api_client({ 'id' => IMAGE_ID }) do |fake|
            file.delete
            assert_equal [IMAGE_ID], fake.deleted_ids
          end

          assert_equal OTHER_IDENTIFIER, model.read_attribute(:resizing_picture)
        end

        def test_delete_treats_not_found_as_success_and_clears_column
          model = model_with_column(IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          with_fake_api_client(NOT_FOUND_RESPONSE) do
            assert_nil file.delete
          end

          assert_nil model.read_attribute(:resizing_picture)
        end

        def test_delete_treats_not_found_of_previous_image_without_clearing_column
          model = model_with_column(OTHER_IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          with_fake_api_client(NOT_FOUND_RESPONSE) { file.delete }

          assert_equal OTHER_IDENTIFIER, model.read_attribute(:resizing_picture)
        end

        def test_delete_raises_api_error_when_response_id_does_not_match
          model = model_with_column(IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          with_fake_api_client({ 'id' => 'someone-else' }) do
            assert_raises(Resizing::APIError) { file.delete }
          end

          # 失敗時はカラムを変更しない
          assert_equal IDENTIFIER, model.read_attribute(:resizing_picture)
        end

        def test_delete_uses_column_value_when_constructed_without_identifier
          # remove! の経路では識別子なしで File が生成され、モデルのカラム値から削除対象を決める
          model = model_with_column(IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture)

          with_fake_api_client({ 'id' => IMAGE_ID }) do |fake|
            file.delete
            assert_equal [IMAGE_ID], fake.deleted_ids
          end

          assert_nil model.read_attribute(:resizing_picture)
        end

        def test_delete_uses_previous_column_value_when_column_has_unsaved_change
          # attribute_was: カラムが変更済み (保存前) の場合は変更前の値の画像を削除する
          model = model_with_column(IDENTIFIER)
          model.save!
          model.send(:write_attribute, :resizing_picture, OTHER_IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture)

          with_fake_api_client({ 'id' => IMAGE_ID }) do |fake|
            file.delete
            assert_equal [IMAGE_ID], fake.deleted_ids
          end

          # 削除したのは古い画像なので、新しい値はそのまま残る
          assert_equal OTHER_IDENTIFIER, model.read_attribute(:resizing_picture)
        end

        def test_delete_does_not_write_column_of_destroyed_model
          model = model_with_column(IDENTIFIER)
          model.save!

          with_fake_api_client({ 'id' => IMAGE_ID }) do |fake|
            ActiveRecord::Base.transaction do
              model.destroy!
            end
            assert model.destroyed?
            assert_equal [IMAGE_ID], fake.deleted_ids

            # destroy 済み (frozen) のモデルに対して delete しても FrozenError にならない
            file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)
            file.delete
          end
        end

        # ============================================================
        # store の詳細な挙動 (Resizing.post を差し替えて送信内容を検証)
        # ============================================================

        POST_RESPONSE = {
          'id' => IMAGE_ID,
          'public_id' => IDENTIFIER,
          'content_type' => 'image/jpeg'
        }.freeze

        def capture_post(response = POST_RESPONSE, &block)
          captured = {}
          responder = lambda do |content, options|
            captured[:content] = content
            captured[:options] = options
            response.dup
          end
          Resizing.stub(:post, responder, &block)
          captured
        end

        def new_storage_file(model = TestModel.new)
          Resizing::CarrierWave::Storage::File.new(model.resizing_picture)
        end

        def test_store_posts_uploaded_file_with_its_content_type_and_original_filename
          file = new_storage_file
          uploaded_file = ActionDispatch::Http::UploadedFile.new(
            filename: 'my photo.jpg',
            type: 'image/jpeg',
            tempfile: ::File.open('test/data/images/sample1.jpg', 'r')
          )

          captured = capture_post { file.store(uploaded_file) }

          assert_equal 'image/jpeg', captured[:options][:content_type]
          assert_equal 'my photo.jpg', captured[:options][:filename]
          assert captured[:content].respond_to?(:read)
          assert_equal 0, captured[:content].pos, 'IO should be rewound before upload'
        end

        def test_store_guesses_content_type_from_extension_for_plain_file
          file = new_storage_file
          source_file = ::File.open('test/data/images/sample1.jpg', 'r')
          source_file.read(10) # 読み進めた状態でも巻き戻して送る

          captured = capture_post { file.store(source_file) }

          assert_equal 'image/jpeg', captured[:options][:content_type]
          assert_equal 'sample1.jpg', captured[:options][:filename]
          assert_equal 0, captured[:content].pos
        end

        # Issue #88: MIME::Types に登録のない拡張子でも例外にならず、
        # application/octet-stream にフォールバックすること
        def test_store_falls_back_to_octet_stream_for_unknown_extension
          # 前提: この拡張子は MIME::Types に登録されていない
          assert_empty MIME::Types.type_for('bookmark.url')

          file = new_storage_file
          tempfile = Tempfile.new(['bookmark', '.url'])
          begin
            tempfile.write("[InternetShortcut]\nURL=https://example.com/\n")
            tempfile.rewind

            captured = capture_post { file.store(tempfile) }

            assert_equal 'application/octet-stream', captured[:options][:content_type]
            assert_equal ::File.basename(tempfile.path), captured[:options][:filename]
          ensure
            tempfile.close!
          end
        end

        def test_guess_content_type_falls_back_for_unknown_or_missing_path
          file = new_storage_file

          assert_equal 'image/jpeg', file.send(:guess_content_type, 'sample1.jpg')
          assert_equal 'application/octet-stream', file.send(:guess_content_type, 'bookmark.url')
          assert_equal 'application/octet-stream', file.send(:guess_content_type, 'no_extension')
          assert_equal 'application/octet-stream', file.send(:guess_content_type, nil)
        end

        def test_store_sends_basename_only_as_filename
          file = new_storage_file
          uploaded_file = ActionDispatch::Http::UploadedFile.new(
            filename: '/some/dir/photo.jpg',
            type: 'image/jpeg',
            tempfile: ::File.open('test/data/images/sample1.jpg', 'r')
          )

          captured = capture_post { file.store(uploaded_file) }

          assert_equal 'photo.jpg', captured[:options][:filename]
        end

        def test_store_writes_public_id_into_model_column
          model = TestModel.new
          file = new_storage_file(model)

          capture_post { file.store(::File.open('test/data/images/sample1.jpg', 'r')) }

          assert_equal IDENTIFIER, model.read_attribute(:resizing_picture)
          assert_equal IDENTIFIER, file.public_id.to_s
          assert_equal IDENTIFIER, file.current_path
          assert_equal IMAGE_ID, file.public_id.image_id
        end

        def test_store_uses_content_type_from_response
          file = new_storage_file
          response = POST_RESPONSE.merge('content_type' => 'image/webp')

          capture_post(response) { file.store(::File.open('test/data/images/sample1.jpg', 'r')) }

          assert_equal 'image/webp', file.content_type
        end

        def test_store_returns_true
          file = new_storage_file
          result = nil

          capture_post { result = file.store(::File.open('test/data/images/sample1.jpg', 'r')) }

          assert_equal true, result
        end

        def test_store_raises_for_storage_file_instance
          model = TestModel.new
          file = new_storage_file(model)
          other = new_storage_file(model)

          assert_raises(NotImplementedError) { file.store(other) }
        end

        # ============================================================
        # current_path / name / public_id
        # ============================================================

        def test_current_path_falls_back_to_model_column
          model = model_with_column(IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture)

          assert_equal IDENTIFIER, file.current_path
          assert_equal IDENTIFIER, file.path
        end

        def test_current_path_prefers_identifier_over_model_column
          model = model_with_column(OTHER_IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          assert_equal IDENTIFIER, file.current_path
        end

        def test_name_reads_from_model_column_not_identifier
          model = model_with_column(OTHER_IDENTIFIER)
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          assert_equal 'new-image-id-2222-2222-222222222222', file.name
        end

        def test_public_id_exposes_parsed_parts
          model = TestModel.new
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          assert_equal IMAGE_ID, file.public_id.image_id
          assert_equal 'e06e710d-f026-4dcf-b2c0-eab0de8bb83f', file.public_id.project_id
          assert_equal '_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e', file.public_id.version
        end

        def test_retrieve_replaces_public_id
          model = TestModel.new
          file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

          file.retrieve(OTHER_IDENTIFIER)

          assert_equal OTHER_IDENTIFIER, file.public_id.to_s
          assert_equal OTHER_IDENTIFIER, file.current_path
        end

        def test_delete_with_valid_public_id_clears_model_column
          VCR.use_cassette 'carrier_wave_test/remove_resizing_picture', record: :none do
            model = model_with_column(IDENTIFIER)
            file = Resizing::CarrierWave::Storage::File.new(model.resizing_picture, IDENTIFIER)

            file.delete

            assert_nil model.read_attribute(:resizing_picture)
          end
        end
      end
    end
  end
end
