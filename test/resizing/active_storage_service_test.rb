# frozen_string_literal: true

require 'test_helper'

module Resizing
  module ActiveStorage
    module Service
      class ResizingServiceTest < Minitest::Test
        def setup
          @service = Resizing::ActiveStorage::Service::ResizingService.new
        end

        def teardown
          # NOP
        end

        def test_service_initialization
          assert_instance_of Resizing::ActiveStorage::Service::ResizingService, @service
        end

        def test_upload_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.upload('test_key', StringIO.new('test data'))
          end
        end

        def test_download_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.download('test_key')
          end
        end

        def test_download_chunk_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.download_chunk('test_key', 0..99)
          end
        end

        def test_delete_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.delete('test_key')
          end
        end

        def test_exist_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.exist?('test_key')
          end
        end

        def test_url_for_direct_upload_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.url_for_direct_upload(
              'test_key',
              expires_in: 3600,
              content_type: 'image/png',
              conteont_length: 1024,
              checksum: 'test_checksum'
            )
          end
        end

        def test_headers_for_direct_upload_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.headers_for_direct_upload(
              'test_key',
              content_type: 'image/png',
              checksum: 'test_checksum'
            )
          end
        end

        def test_private_url_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.send(
              :private_url,
              'test_key',
              expires_in: 3600,
              filename: 'test.png',
              content_type: 'image/png',
              disposition: :attachment
            )
          end
        end

        def test_public_url_raises_not_implemented_error
          assert_raises NotImplementedError do
            @service.send(
              :public_url,
              'test_key',
              filename: 'test.png'
            )
          end
        end
      end
    end
  end
end
