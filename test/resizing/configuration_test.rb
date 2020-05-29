require "test_helper"

module Resizing
  class ConfigurationTest < Minitest::Test
    def setup
      @template = {
        host: 'https://test.example.com',
        project_id: 'project_id',
        secret_token: 'secret_token',
        open_timeout: 10,
        response_timeout: 20,
      }.freeze
    end

    def teardown
      # NOP
    end

    def test_that_it_has_default_host
      template = @template.dup
      template.delete(:host)
      config = Resizing::Configuration.new template
      assert_equal(config.host, Resizing::Configuration::DEFAULT_HOST)
    end

    def test_that_it_has_same_host_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.host, template[:host])
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
          'v1,1590698400,475b698ca98abaccd03dc38966615e9f3072ae07055196f63a3a5d2a3b18d818',
          config.generate_auth_header
        )
      end
    end

    def test_that_it_return_image_url
      template = @template.dup
      image_id = 'some-image-id'
      config = Resizing::Configuration.new template
      assert_equal(
        'https://test.example.com/projects/project_id/upload/images/some-image-id',
        config.generate_image_url(image_id)
      )
    end

    def test_that_it_return_image_url_with_version_id
      template = @template.dup
      image_id = 'some-image-id'
      version_id = 'version-id'
      config = Resizing::Configuration.new template
      assert_equal(
        'https://test.example.com/projects/project_id/upload/images/some-image-id/vversion-id',
        config.generate_image_url(image_id, version_id)
      )
    end

    def test_that_it_return_transformation_path
      data = [
        {args: {w: 100}, path: 'w_100'},
        {args: {h: 100}, path: 'h_100'},
        {args: {f: 'webp'}, path: 'f_webp'},
        {args: {c: 'fill'}, path: 'c_fill'},
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
      assert_match %r(/projects/#{config.project_id}/upload/images/[\da-z-]), config.generate_identifier
    end
  end
end
