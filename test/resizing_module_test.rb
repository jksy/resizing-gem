# frozen_string_literal: true

require 'test_helper'

class ResizingModuleTest < Minitest::Test
  def setup
    # Reset configure before each test to ensure clean state
    return unless Resizing.instance_variable_defined?(:@configure)

    Resizing.remove_instance_variable(:@configure)
  end

  def teardown
    # Reset configure after each test
    return unless Resizing.instance_variable_defined?(:@configure)

    Resizing.remove_instance_variable(:@configure)
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

  def test_generate_identifier_returns_identifier_string
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123'
    }

    identifier = Resizing.generate_identifier

    assert_instance_of String, identifier
    assert_includes identifier, 'project123'
    assert_match %r{/projects/project123/upload/images/}, identifier
  end

  def test_client_returns_mock_client_when_enable_mock_is_true
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123',
      enable_mock: true
    }

    client = Resizing.client

    assert_instance_of Resizing::MockClient, client
  end

  def test_client_returns_real_client_when_enable_mock_is_false
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123',
      enable_mock: false
    }

    client = Resizing.client

    assert_instance_of Resizing::Client, client
  end

  def test_put_delegates_to_client
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123',
      enable_mock: true
    }

    result = Resizing.put('image_id', 'dummy', content_type: 'image/jpeg')

    assert_instance_of Hash, result
    assert_equal 'image_id', result['id']
  end

  def test_delete_delegates_to_client
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123',
      enable_mock: true
    }

    result = Resizing.delete('image_id')

    assert_instance_of Hash, result
    assert_equal 'image_id', result['id']
  end

  def test_metadata_delegates_to_client
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123',
      enable_mock: true
    }

    result = Resizing.metadata('image_id', {})

    assert_instance_of Hash, result
    assert_equal 'image_id', result['id']
  end

  def test_post_delegates_to_client
    Resizing.configure = {
      image_host: 'https://img.example.com',
      project_id: 'project123',
      secret_token: 'token123',
      enable_mock: true
    }

    result = Resizing.post('test/data/images/sample1.jpg', content_type: 'image/jpeg')

    assert_instance_of Hash, result
    assert_equal '87263920-2081-498e-a107-9625f4fde01b', result['id']
  end

  def test_client_raises_configuration_error_when_not_configured
    assert_raises(Resizing::ConfigurationError) { Resizing.client }
  end

  def test_api_methods_raise_configuration_error_when_not_configured
    assert_raises(Resizing::ConfigurationError) { Resizing.post('dummy', content_type: 'image/jpeg') }
    assert_raises(Resizing::ConfigurationError) { Resizing.put('id', 'dummy', content_type: 'image/jpeg') }
    assert_raises(Resizing::ConfigurationError) { Resizing.delete('id') }
    assert_raises(Resizing::ConfigurationError) { Resizing.metadata('id', {}) }
    assert_raises(Resizing::ConfigurationError) { Resizing.url_from_image_id('id') }
    assert_raises(Resizing::ConfigurationError) { Resizing.generate_identifier }
  end

  def test_configure_setter_raises_for_invalid_hash
    assert_raises(Resizing::ConfigurationError) { Resizing.configure = { project_id: 'only-project' } }
    assert_raises(Resizing::ConfigurationError) { Resizing.configure = { secret_token: 'only-token' } }
    assert_raises(Resizing::ConfigurationError) do
      Resizing.configure = { project_id: 'p', secret_token: 's', host: 'deprecated-host' }
    end
  end

  def test_configure_setter_replaces_previous_configuration
    Resizing.configure = { project_id: 'first', secret_token: 'token' }
    Resizing.configure = { project_id: 'second', secret_token: 'token' }

    assert_equal 'second', Resizing.configure.project_id
  end

  def test_client_reflects_latest_configuration
    Resizing.configure = { project_id: 'p', secret_token: 's', enable_mock: false }
    assert_instance_of Resizing::Client, Resizing.client

    Resizing.configure = { project_id: 'p', secret_token: 's', enable_mock: true }
    assert_instance_of Resizing::MockClient, Resizing.client
  end

  def test_separate_public_id_extracts_project_id_image_id_and_version
    matched = Resizing.separate_public_id(
      '/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/28c49144-c00d-4cb5-8619-98ce95977b9c/v1Id850q34fgsaer23w'
    )

    assert_equal '098a2a0d-c387-4135-a071-1254d6d7e70a', matched[:project_id]
    assert_equal '28c49144-c00d-4cb5-8619-98ce95977b9c', matched[:image_id]
    assert_equal '1Id850q34fgsaer23w', matched[:version]
  end

  def test_separate_public_id_without_version
    matched = Resizing.separate_public_id(
      '/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/28c49144-c00d-4cb5-8619-98ce95977b9c'
    )

    assert_equal '28c49144-c00d-4cb5-8619-98ce95977b9c', matched[:image_id]
    assert_nil matched[:version]
  end

  def test_separate_public_id_returns_nil_for_unrelated_string
    assert_nil Resizing.separate_public_id('/foo/bar')
    assert_nil Resizing.separate_public_id('')
  end

  def test_generate_identifier_returns_new_value_each_time
    Resizing.configure = { project_id: '098a2a0d-c387-4135-a071-1254d6d7e70a', secret_token: 'token' }

    first = Resizing.generate_identifier
    second = Resizing.generate_identifier

    refute_equal first, second
    # 生成した identifier は PublicId として解釈できる
    assert_equal '098a2a0d-c387-4135-a071-1254d6d7e70a', Resizing::PublicId.new(first).project_id
  end

  def test_url_from_image_id_uses_default_image_host_when_not_specified
    Resizing.configure = { project_id: 'project123', secret_token: 'token123' }

    assert_equal 'https://img.resizing.net/projects/project123/upload/images/image456', Resizing.url_from_image_id('image456')
  end
end
