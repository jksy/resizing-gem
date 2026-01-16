# frozen_string_literal: true

require 'test_helper'

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
      end
    end
  end
end
