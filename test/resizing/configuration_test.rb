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
        config = Resizing::Configuration.new template
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
        config = Resizing::Configuration.new template
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

    def test_it_does_something_useful
      # assert false
    end
  end
end
