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
      end
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
        # The cassette contains a fixed public_id, so we just check it exists
        assert result.key?('public_id')
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
  end
end
