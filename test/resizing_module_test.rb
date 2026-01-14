# frozen_string_literal: true

require 'test_helper'

class ResizingModuleTest < Minitest::Test
  def teardown
    # Reset configure after each test
    if Resizing.instance_variable_defined?(:@configure)
      Resizing.remove_instance_variable(:@configure)
    end
  end

  def test_configure_raises_error_when_not_initialized
    assert_raises Resizing::ConfigurationError do
      Resizing.configure
    end
  end

  def test_configure_returns_duplicate_of_configuration
    config = Resizing::Configuration.new(
      image_host: 'https://test.example.com',
      project_id: 'test_id',
      secret_token: 'test_token'
    )
    Resizing.configure = config

    result = Resizing.configure

    assert_instance_of Resizing::Configuration, result
    assert_equal config.image_host, result.image_host
    assert_equal config.project_id, result.project_id
    refute_equal config.object_id, result.object_id # Should be a duplicate
  end

  def test_configure_setter_accepts_configuration_object
    config = Resizing::Configuration.new(
      image_host: 'https://test.example.com',
      project_id: 'test_id',
      secret_token: 'test_token'
    )

    Resizing.configure = config

    assert_equal config, Resizing.instance_variable_get(:@configure)
  end

  def test_configure_setter_converts_hash_to_configuration
    config_hash = {
      image_host: 'https://hash.example.com',
      project_id: 'hash_id',
      secret_token: 'hash_token'
    }

    Resizing.configure = config_hash

    result = Resizing.instance_variable_get(:@configure)
    assert_instance_of Resizing::Configuration, result
    assert_equal 'https://hash.example.com', result.image_host
    assert_equal 'hash_id', result.project_id
  end

  def test_get_raises_not_implemented_error
    assert_raises NotImplementedError do
      Resizing.get('test')
    end
  end

  def test_url_from_image_id_returns_url_without_version_and_transforms
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123'
    }

    url = Resizing.url_from_image_id('image456')

    assert_equal 'https://img.example.com/projects/project123/upload/images/image456', url
  end

  def test_url_from_image_id_returns_url_with_version
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123'
    }

    url = Resizing.url_from_image_id('image456', '789')

    assert_equal 'https://img.example.com/projects/project123/upload/images/image456/v789', url
  end

  def test_url_from_image_id_returns_url_with_transformations
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123'
    }

    url = Resizing.url_from_image_id('image456', nil, [{ w: 100, h: 200 }])

    assert_includes url, 'https://img.example.com/projects/project123/upload/images/image456/'
    assert_includes url, 'w_100,h_200'
  end

  def test_url_from_image_id_returns_url_with_version_and_transformations
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123'
    }

    url = Resizing.url_from_image_id('image456', '789', [{ w: 100 }])

    assert_includes url, 'image456/v789/'
    assert_includes url, 'w_100'
  end
end
