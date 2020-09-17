# frozen_string_literal: true

require 'test_helper'

module Resizing
  class PublicIdTest < Minitest::Test
    def setup
      @project_id = '098a2a0d-c387-4135-a071-1254d6d7e70a'
      @image_id = '28c49144-c00d-4cb5-8619-98ce95977b9c'
      @version = '1Id850q34fgsaer23w'
      @public_id_as_string = "/projects/#{@project_id}/upload/images/#{@image_id}/v#{@version}"
    end

    def teardown; end

    def test_expect_equal_project_id
      public_id = Resizing::PublicId.new @public_id_as_string
      assert_equal @project_id, public_id.project_id
    end

    def test_expect_equal_image_id
      public_id = Resizing::PublicId.new @public_id_as_string
      assert_equal @image_id, public_id.image_id
    end

    def test_expect_equal_version
      public_id = Resizing::PublicId.new @public_id_as_string
      assert_equal @version, public_id.version
    end

    def test_expect_equal_identifier
      public_id = Resizing::PublicId.new @public_id_as_string
      assert_equal @public_id_as_string.gsub(/\/v.*$/, ''), public_id.identifier
    end

    def test_expect_equal_public_id
      public_id = Resizing::PublicId.new @public_id_as_string
      assert_equal @public_id_as_string, public_id.to_s
    end
  end
end
