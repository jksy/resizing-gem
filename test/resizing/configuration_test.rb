require "test_helper"

module Resizing
  class ResizingConfigurationTest < Minitest::Test
    def setup
      # @configration = Resizing::Configuration.new
      @template = {
        host: 'hostname',
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

  end
end
