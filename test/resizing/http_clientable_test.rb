# frozen_string_literal: true

require 'test_helper'

module Resizing
  class HttpClientableTest < Minitest::Test
    class TestClient
      include HttpClientable

      def config
        @config ||= Configuration.new(
          image_host: 'https://image.example.com',
          project_id: 'test_project',
          secret_token: 'test_token'
        )
      end
    end

    def setup
      @client = TestClient.new
    end

    def teardown
      # NOP
    end

    def test_http_client_initialization
      http_client = @client.http_client

      assert_instance_of Faraday::Connection, http_client
    end

    def test_http_client_has_open_timeout
      http_client = @client.http_client

      assert_equal @client.config.open_timeout, http_client.options[:open_timeout]
    end

    def test_http_client_has_response_timeout
      http_client = @client.http_client

      assert_equal @client.config.response_timeout, http_client.options[:timeout]
    end

    def test_http_client_is_cached
      http_client1 = @client.http_client
      http_client2 = @client.http_client

      assert_equal http_client1.object_id, http_client2.object_id
    end

    def test_handle_faraday_error_yields_block
      result = @client.handle_faraday_error { 'test_result' }

      assert_equal 'test_result', result
    end

    def test_handle_faraday_error_catches_timeout_error
      assert_raises Resizing::APIError do
        @client.handle_faraday_error do
          raise Faraday::TimeoutError, 'timeout'
        end
      end
    end

    def test_handle_timeout_error_raises_api_error
      error = Faraday::TimeoutError.new('test timeout')

      assert_raises Resizing::APIError do
        @client.handle_timeout_error(error)
      end
    end

    def test_handle_timeout_error_message_includes_error_info
      error = Faraday::TimeoutError.new('test timeout')

      begin
        @client.handle_timeout_error(error)
      rescue Resizing::APIError => e
        assert_includes e.message, 'TimeoutError'
      end
    end

    def test_http_client_uses_multipart_and_url_encoded_request_middleware
      handlers = @client.http_client.builder.handlers

      assert_includes handlers, Faraday::Multipart::Middleware
      assert_includes handlers, Faraday::Request::UrlEncoded
    end

    def test_handle_faraday_error_does_not_rescue_other_faraday_errors
      # TimeoutError 以外の Faraday エラーはそのまま伝播する (現状の仕様)
      assert_raises Faraday::ConnectionFailed do
        @client.handle_faraday_error { raise Faraday::ConnectionFailed, 'connection refused' }
      end
    end

    def test_handle_faraday_error_does_not_rescue_non_faraday_errors
      assert_raises RuntimeError do
        @client.handle_faraday_error { raise 'unexpected' }
      end
    end

    def test_handle_timeout_error_message_includes_original_message
      error = Faraday::TimeoutError.new('execution expired')

      raised = assert_raises(Resizing::APIError) { @client.handle_timeout_error(error) }
      assert_includes raised.message, 'execution expired'
    end
  end
end
