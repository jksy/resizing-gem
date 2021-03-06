# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ConfigurationTest < Minitest::Test
    def setup
      @template = {
        image_host: 'http://192.168.56.101:5000',
        video_host: 'http://192.168.56.101:5000',
        project_id: '098a2a0d-c387-4135-a071-1254d6d7e70a',
        secret_token: '4g1cshg2lq8j93ufhvqrpjswxmtjz12yhfvq6w79jpwi7cr7nnknoqgwzkwerbs6',
        open_timeout: 10,
        response_timeout: 20
      }.freeze
    end

    def teardown
      # NOP
    end

    def test_that_it_has_default_image_host
      template = @template.dup
      template.delete(:image_host)
      config = Resizing::Configuration.new template
      assert_equal(config.host, Resizing::Configuration::DEFAULT_IMAGE_HOST)
      assert_equal(config.image_host, Resizing::Configuration::DEFAULT_IMAGE_HOST)
    end

    def test_that_it_has_default_video_host
      template = @template.dup
      template.delete(:video_host)
      config = Resizing::Configuration.new template
      assert_equal(config.video_host, Resizing::Configuration::DEFAULT_VIDEO_HOST)
    end

    def test_that_it_need_raise_exception_if_host_presented
      template = @template.dup
      template[:host] = 'need raise execption if host is presented'
      assert_raises ConfigurationError do
        config = Resizing::Configuration.new template
      end
    end

    def test_that_it_has_same_image_host_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.image_host, template[:image_host])
    end

    def test_that_it_has_same_video_host_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.video_host, template[:video_host])
    end

    def test_that_it_has_no_project_id
      template = @template.dup
      template.delete(:project_id)
      assert_raises ConfigurationError do
        Resizing::Configuration.new template
      end
    end

    def test_that_it_has_same_project_id_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.project_id, template[:project_id])
    end

    def test_that_it_has_no_secret_token
      template = @template.dup
      template.delete(:project_id)
      assert_raises ConfigurationError do
        Resizing::Configuration.new template
      end
    end

    def test_that_it_has_same_secret_token_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.secret_token, template[:secret_token])
    end

    def test_that_it_has_default_open_timeout
      template = @template.dup
      template.delete(:open_timeout)
      config = Resizing::Configuration.new template
      assert_equal(config.open_timeout, Resizing::Configuration::DEFAULT_OPEN_TIMEOUT)
    end

    def test_that_it_has_same_open_timeout
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.open_timeout, template[:open_timeout])
    end

    def test_that_it_return_auth_header_token
      Timecop.freeze(Time.parse('2020-05-29 05:40:00 +0900')) do
        template = @template.dup
        config = Resizing::Configuration.new template
        assert_equal(
          'v1,1590698400,2b35ee78cd6ce32edb9b4d97b69306c678ce8dea871638ff6144b7be0d26173c',
          config.generate_auth_header
        )
      end
    end

    def test_that_it_return_image_url
      template = @template.dup
      image_id = 'some-image-id'
      config = Resizing::Configuration.new template
      assert_equal(
        'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id',
        config.generate_image_url(image_id)
      )
    end

    def test_that_it_return_image_url_with_version_id
      template = @template.dup
      image_id = 'some-image-id'
      version_id = 'version-id'
      config = Resizing::Configuration.new template
      assert_equal(
        'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id/vversion-id',
        config.generate_image_url(image_id, version_id)
      )
    end

    def test_that_it_return_transformation_path
      data = [
        { args: { w: 100 }, path: 'w_100' },
        { args: { h: 100 }, path: 'h_100' },
        { args: { f: 'webp' }, path: 'f_webp' },
        { args: { c: 'fill' }, path: 'c_fill' }
      ]
      config = Resizing::Configuration.new @template
      data.each do |v|
        assert_equal(
          v[:path],
          config.transformation_path(v[:args])
        )
      end
    end

    def test_that_it_generated_identifier_path
      config = Resizing::Configuration.new @template
      assert_match %r{/projects/#{config.project_id}/upload/images/[\da-z-]}, config.generate_identifier
    end
  end
end
