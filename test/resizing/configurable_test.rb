# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ConfigurableTest < Minitest::Test
    class TestConfigurable
      include Configurable

      def initialize(config = nil)
        initialize_config(config)
      end
    end

    def setup
      # NOP
    end

    def teardown
      # NOP
    end

    def test_initialize_config_with_configuration_object
      config = Configuration.new(
        image_host: 'https://test.example.com',
        project_id: 'test_id',
        secret_token: 'test_token'
      )
      obj = TestConfigurable.new(config)

      assert_equal config, obj.config
    end

    def test_initialize_config_with_nil_uses_global_configure
      Resizing.configure = Configuration.new(
        image_host: 'https://global.example.com',
        project_id: 'global_id',
        secret_token: 'global_token'
      )

      obj = TestConfigurable.new(nil)

      assert_equal Resizing.configure.image_host, obj.config.image_host
    end

    def test_initialize_config_with_hash
      config_hash = {
        image_host: 'https://hash.example.com',
        project_id: 'hash_id',
        secret_token: 'hash_token'
      }
      obj = TestConfigurable.new(config_hash)

      assert_equal 'https://hash.example.com', obj.config.image_host
      assert_equal 'hash_id', obj.config.project_id
    end

    def test_config_is_accessible
      config = Configuration.new(
        image_host: 'https://test.example.com',
        project_id: 'test_id',
        secret_token: 'test_token'
      )
      obj = TestConfigurable.new(config)

      assert_instance_of Configuration, obj.config
    end

    def test_attr_reader_config_is_defined
      config = Configuration.new(
        image_host: 'https://test.example.com',
        project_id: 'test_id',
        secret_token: 'test_token'
      )
      obj = TestConfigurable.new(config)

      # Verify that config is accessible as a reader
      assert obj.respond_to?(:config)
      assert !obj.respond_to?(:config=)
    end
  end
end
