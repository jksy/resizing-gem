# frozen_string_literal: true

require 'test_helper'

module Resizing
  class MockClientTest < Minitest::Test
    def setup
      @client = Resizing::MockClient.new
    end

    def teardown
      # NOP
    end

    def test_post_returns_parsed_json
      VCR.use_cassette('client/post', record: :none) do
        result = @client.post(nil)

        assert_instance_of Hash, result
        assert result.key?('id')
        assert result.key?('public_id')
        assert result.key?('latest_version_id')
        assert result.key?('latest_etag')
      end
    end

    def test_put_returns_parsed_json_with_modified_name
      VCR.use_cassette('client/put', record: :none) do
        name = 'test-image-123'
        result = @client.put(name, nil, {})

        assert_instance_of Hash, result
        assert_equal name, result['id']
        assert_includes result['public_id'], name
        assert result.key?('latest_version_id')
        assert result.key?('latest_etag')

        # id と public_id の image_id が一致していること
        public_id = Resizing::PublicId.new(result['public_id'])
        assert_equal name, public_id.image_id
        # カセットに含まれる元の image_id が残っていないこと
        refute_includes result['public_id'], 'AWEaewfAreaweFAFASfwe'
        # version がカセットの固定値から更新されていること
        refute_equal 'fztekhN_WoeXo8ZkCZ4i5jcQvmPpZewR', result['version']
        refute_includes result['public_id'], 'vfztekhN_WoeXo8ZkCZ4i5jcQvmPpZewR'
        # version / latest_version_id / public_id の version が揃っていること
        assert_equal result['version'], public_id.version
        assert_equal result['latest_version_id'], public_id.version
      end
    end

    def test_put_generates_new_version_for_each_call
      name = 'test-image-123'
      first = @client.put(name, nil, {})
      second = @client.put(name, nil, {})

      refute_equal first['version'], second['version']
      refute_equal first['public_id'], second['public_id']
    end

    def test_metadata_returns_public_id_for_given_name
      name = 'metadata-test-image'
      result = @client.metadata(name)
      public_id = Resizing::PublicId.new(result['public_id'])

      assert_equal result['id'], public_id.image_id
      assert_equal name, public_id.image_id
    end

    def test_delete_keeps_version_from_cassette
      name = 'delete-test-image'
      result = @client.delete(name)
      public_id = Resizing::PublicId.new(result['public_id'])

      assert_equal name, public_id.image_id
      assert_equal result['project_id'], public_id.project_id
      assert_equal result['latest_version_id'], public_id.version
      refute_includes result['public_id'], '28c49144-c00d-4cb5-8619-98ce95977b9c'
    end

    def test_delete_returns_parsed_json_with_modified_name
      VCR.use_cassette('client/delete', record: :none) do
        name = 'delete-test-image'
        result = @client.delete(name)

        assert_instance_of Hash, result
        assert_equal name, result['id']
        assert_includes result['public_id'], name
      end
    end

    def test_metadata_returns_parsed_json_with_modified_name
      VCR.use_cassette('client/metadata', record: :none) do
        name = 'metadata-test-image'
        result = @client.metadata(name)

        assert_instance_of Hash, result
        assert_equal name, result['id']
        assert result.key?('public_id')

        # id と public_id の image_id が一致していること
        public_id = Resizing::PublicId.new(result['public_id'])
        assert_equal name, public_id.image_id
        assert_equal result['id'], public_id.image_id
        # カセットに含まれる元の image_id が残っていないこと
        refute_includes result['public_id'], '87263920-2081-498e-a107-9625f4fde01b'
        # project_id と version はカセットの値を引き継ぐこと
        assert_equal result['project_id'], public_id.project_id
        assert_equal result['version'], public_id.version
      end
    end

    def test_post_response_contains_expected_fields
      VCR.use_cassette('client/post', record: :none) do
        result = @client.post(nil)

        # Verify response structure
        assert result['id'].is_a?(String)
        assert result['public_id'].is_a?(String)
        assert result['latest_version_id'].is_a?(String)
        assert result['latest_etag'].is_a?(String)
      end
    end

    def test_mock_client_does_not_perform_http_requests
      # VCR はカセット外の HTTP 接続を禁止しているため、カセットなしで成功すれば通信していないことが分かる
      post_result = @client.post('test/data/images/sample1.jpg', content_type: 'image/jpeg')
      assert_equal '87263920-2081-498e-a107-9625f4fde01b', post_result['id']

      refute_nil @client.put('img', nil, {})
      refute_nil @client.delete('img')
      refute_nil @client.metadata('img')
    end

    def test_post_returns_public_id_parsable_by_public_id
      result = @client.post(nil)
      public_id = Resizing::PublicId.new(result['public_id'])

      assert_equal result['id'], public_id.image_id
      assert_equal result['project_id'], public_id.project_id
      assert_equal result['latest_version_id'], public_id.version
    end

    def test_put_returns_public_id_for_given_name
      name = 'test-image-123'
      result = @client.put(name, nil, {})
      public_id = Resizing::PublicId.new(result['public_id'])

      assert_equal name, public_id.image_id
      refute_nil public_id.version
    end

    def test_delete_returns_public_id_for_given_name
      name = 'delete-test-image'
      result = @client.delete(name)
      public_id = Resizing::PublicId.new(result['public_id'])

      assert_equal name, public_id.image_id
    end

    def test_each_call_returns_independent_result
      first = @client.post(nil)
      second = @client.post(nil)

      refute_same first, second
      first['id'] = 'changed'
      first['public_id'] << '/changed'
      assert_equal '87263920-2081-498e-a107-9625f4fde01b', second['id']
      refute_includes second['public_id'], 'changed'
    end

    def test_mock_client_is_selected_by_resizing_module_when_enable_mock
      Resizing.configure = {
        image_host: 'https://img.example.com',
        project_id: 'project123',
        secret_token: 'token123',
        enable_mock: true
      }

      result = Resizing.post('test/data/images/sample1.jpg', content_type: 'image/jpeg')

      assert_equal '87263920-2081-498e-a107-9625f4fde01b', result['id']
    end
  end
end
