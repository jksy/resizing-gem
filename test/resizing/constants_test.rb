# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ConstantsTest < Minitest::Test
    def test_http_status_ok_is_defined
      assert_equal 200, Resizing::Constants::HTTP_STATUS_OK
    end

    def test_http_status_created_is_defined
      assert_equal 201, Resizing::Constants::HTTP_STATUS_CREATED
    end

    def test_http_status_not_found_is_defined
      assert_equal 404, Resizing::Constants::HTTP_STATUS_NOT_FOUND
    end

    def test_constants_are_integers
      assert_instance_of Integer, Resizing::Constants::HTTP_STATUS_OK
      assert_instance_of Integer, Resizing::Constants::HTTP_STATUS_CREATED
      assert_instance_of Integer, Resizing::Constants::HTTP_STATUS_NOT_FOUND
    end
  end
end
