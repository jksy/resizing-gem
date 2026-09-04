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
      assert_equal @public_id_as_string.gsub(%r{/v.*$}, ''), public_id.identifier
    end

    def test_expect_equal_public_id
      public_id = Resizing::PublicId.new @public_id_as_string
      assert_equal @public_id_as_string, public_id.to_s
    end

    def test_empty_is_false_for_valid_public_id
      public_id = Resizing::PublicId.new @public_id_as_string
      refute public_id.empty?
    end

    def test_filename_returns_image_id
      public_id = Resizing::PublicId.new @public_id_as_string
      assert_equal @image_id, public_id.filename
    end

    def test_version_is_nil_when_public_id_has_no_version
      public_id = Resizing::PublicId.new "/projects/#{@project_id}/upload/images/#{@image_id}"

      assert_nil public_id.version
      assert_equal @image_id, public_id.image_id
      assert_equal @project_id, public_id.project_id
      assert_equal "/projects/#{@project_id}/upload/images/#{@image_id}", public_id.identifier
    end

    def test_version_may_start_with_underscore
      # 実際の API が返すバージョン ID の形式 (test/vcr/carrier_wave_test/save.yml より)
      public_id = Resizing::PublicId.new "/projects/#{@project_id}/upload/images/#{@image_id}/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e"

      assert_equal '_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e', public_id.version
      assert_equal @image_id, public_id.image_id
    end

    def test_nil_public_id_is_empty_and_has_no_parts
      public_id = Resizing::PublicId.new nil

      assert public_id.empty?
      assert_nil public_id.image_id
      assert_nil public_id.project_id
      assert_nil public_id.version
      assert_equal '', public_id.to_s
    end

    def test_empty_string_public_id_is_empty_and_has_no_parts
      public_id = Resizing::PublicId.new ''

      assert public_id.empty?
      assert_nil public_id.image_id
      assert_nil public_id.project_id
      assert_nil public_id.version
      assert_equal '', public_id.to_s
    end

    def test_empty_string_public_id_does_not_raise
      # Issue #94: nil は許容されるのに空文字は RuntimeError になっていた
      Resizing::PublicId.new ''
    end

    def test_empty_string_public_id_behaves_same_as_nil
      from_empty_string = Resizing::PublicId.new ''
      from_nil = Resizing::PublicId.new nil

      parts = ->(public_id) { [public_id.empty?, public_id.image_id, public_id.project_id, public_id.version, public_id.to_s] }

      assert_equal parts.call(from_nil), parts.call(from_empty_string)
    end

    def test_whitespace_only_public_id_is_treated_as_empty
      public_id = Resizing::PublicId.new "  \t\n "

      assert public_id.empty?
      assert_nil public_id.image_id
      assert_nil public_id.project_id
      assert_nil public_id.version
    end

    def test_invalid_public_id_raises_error
      assert_raises(RuntimeError) { Resizing::PublicId.new 'not/a/public/id' }
      assert_raises(RuntimeError) { Resizing::PublicId.new "/projects/#{@project_id}/upload/videos/#{@image_id}" }
    end

    def test_project_id_must_consist_of_hex_digits_and_hyphens
      # public_id の project_id 部分は UUID 形式 ([0-9a-f-]+) のみ受け付ける
      assert_raises(RuntimeError) { Resizing::PublicId.new "/projects/project123/upload/images/#{@image_id}" }
    end

    def test_image_id_accepts_non_uuid_value
      public_id = Resizing::PublicId.new "/projects/#{@project_id}/upload/images/AWEaewfAreaweFAFASfwe/vabc"

      assert_equal 'AWEaewfAreaweFAFASfwe', public_id.image_id
      assert_equal 'abc', public_id.version
    end

    def test_parses_public_id_embedded_in_full_url
      # match はアンカーなしのため image_host 付きの URL からも各要素を取り出せる
      public_id = Resizing::PublicId.new "https://img.resizing.net#{@public_id_as_string}"

      assert_equal @project_id, public_id.project_id
      assert_equal @image_id, public_id.image_id
      assert_equal @version, public_id.version
    end
  end
end
