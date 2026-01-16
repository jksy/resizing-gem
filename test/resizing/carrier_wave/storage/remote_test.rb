# frozen_string_literal: true

require 'test_helper'

module Resizing
  module CarrierWave
    module Storage
      class RemoteTest < Minitest::Test
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

          model = TestModel.new
          @uploader = model.resizing_picture
          @storage = Remote.new(@uploader)
        end

        def teardown
          # NOP
        end

        def test_storage_has_required_methods
          assert_respond_to @storage, :store!
          assert_respond_to @storage, :remove!
          assert_respond_to @storage, :cache!
          assert_respond_to @storage, :retrieve_from_cache!
          assert_respond_to @storage, :delete_dir!
          assert_respond_to @storage, :clean_cache!
        end

        def test_retrieve_from_cache_returns_nil
          result = @storage.retrieve_from_cache!('identifier')
          assert_nil result
        end

        def test_delete_dir_does_nothing
          # Should not raise any exception
          assert_nil @storage.delete_dir!('/path/to/dir')
        end

        def test_clean_cache_does_nothing
          # Should not raise any exception
          assert_nil @storage.clean_cache!(3600)
        end

        def test_storage_initialization
          assert_instance_of Remote, @storage
        end

        def test_retrieve_returns_nil_for_blank_identifier
          result = @storage.retrieve!(nil)
          assert_nil result

          result = @storage.retrieve!('')
          assert_nil result
        end

        def test_retrieve_returns_file_for_valid_identifier
          identifier = '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
          result = @storage.retrieve!(identifier)

          assert_instance_of Resizing::CarrierWave::Storage::File, result
          assert_equal identifier, result.public_id.to_s
        end
      end
    end
  end
end
