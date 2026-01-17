# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ErrorTest < Minitest::Test
    def test_error_is_standard_error_subclass
      assert Resizing::Error < StandardError
    end

    def test_configuration_error_is_error_subclass
      assert Resizing::ConfigurationError < Resizing::Error
    end

    def test_api_error_is_error_subclass
      assert Resizing::APIError < Resizing::Error
    end

    def test_api_error_has_decoded_body_accessor
      error = Resizing::APIError.new('test error')

      assert_respond_to error, :decoded_body
      assert_respond_to error, :decoded_body=
    end

    def test_api_error_decoded_body_defaults_to_empty_hash
      error = Resizing::APIError.new('test error')

      assert_equal({}, error.decoded_body)
    end

    def test_api_error_decoded_body_can_be_set_with_hash
      error = Resizing::APIError.new('test error')
      body = { 'error' => 'test', 'code' => 400 }

      error.decoded_body = body

      assert_equal body, error.decoded_body
    end

    def test_api_error_decoded_body_raises_argument_error_for_non_hash
      error = Resizing::APIError.new('test error')

      assert_raises ArgumentError do
        error.decoded_body = 'not a hash'
      end
    end

    def test_api_error_decoded_body_raises_argument_error_for_array
      error = Resizing::APIError.new('test error')

      assert_raises ArgumentError do
        error.decoded_body = %w[not a hash]
      end
    end

    def test_configuration_error_can_be_raised_with_message
      error = assert_raises Resizing::ConfigurationError do
        raise Resizing::ConfigurationError, 'test configuration error'
      end

      assert_equal 'test configuration error', error.message
    end

    def test_api_error_can_be_raised_with_message
      error = assert_raises Resizing::APIError do
        raise Resizing::APIError, 'test api error'
      end

      assert_equal 'test api error', error.message
    end
  end
end
