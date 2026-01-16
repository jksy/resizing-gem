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
      end
    end
  end
end
