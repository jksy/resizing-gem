# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ClientTest < Minitest::Test
    def setup
      # NOP
      @configuration_template = {
        host: 'http://192.168.56.101:5000',
        project_id: '098a2a0d-c387-4135-a071-1254d6d7e70a',
        secret_token: '4g1cshg2lq8j93ufhvqrpjswxmtjz12yhfvq6w79jpwi7cr7nnknoqgwzkwerbs6',
        open_timeout: 10,
        response_timeout: 20
      }
    end

    def teardown
      # NOP
    end

    def test_is_initialized
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      assert(!client.config.nil?)
      assert_equal(client.config, Resizing.configure)
    end

    def test_is_initialized_with_configuration
      config = Resizing::Configuration.new(@configuration_template)
      client = Resizing::Client.new(config)
      assert(!client.config.nil?)
      assert_equal(client.config, config)
    end

    def test_is_postable_file
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/post', record: :once  do
        f = File.open('test/data/images/sample1.jpg', 'r')
        r = client.post(f, content_type: 'image/jpeg')
        assert_equal(r['id'], 'bfdaf2b3-7ec5-41f4-9caa-d53247dd9666')
        assert_equal(r['project_id'], Resizing.configure.project_id)
        assert_equal(r['content_type'], 'image/jpeg')
        assert(!r['latest_version_id'].nil?)
        assert(!r['latest_etag'].nil?)
        assert(!r['created_at'].nil?)
        assert(!r['updated_at'].nil?)
        assert_equal(r['public_id'], '/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/bfdaf2b3-7ec5-41f4-9caa-d53247dd9666/vAyWaxx96gLaAzB9Bq.VbX1_pxfXJ0Jcq')
        assert_equal(r['filename'], 'sample1.jpg')
      end
    end

    def test_is_putable_file
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/put', record: :once do
        f = File.open('test/data/images/sample1.jpg', 'r')
        name = 'AWEaewfAreaweFAFASfwe'
        r = client.put(name, f, content_type: 'image/jpeg')
        assert_equal(r['id'], name)
        assert_equal(r['project_id'], Resizing.configure.project_id)
        assert_equal(r['content_type'], 'image/jpeg')
        assert(!r['latest_version_id'].nil?)
        assert(!r['latest_etag'].nil?)
        assert(!r['created_at'].nil?)
        assert(!r['updated_at'].nil?)
        assert_equal(
          r['public_id'],
          "/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/#{name}/v6Ew3HmDAYfb3NMRdLxR45i_gXMbLlGyi"
        )
      end
    end

    def test_get_the_metadata
      # TODO

      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/metadata', record: :once do
        name = 'bfdaf2b3-7ec5-41f4-9caa-d53247dd9666'
        r = client.metadata(name)
        assert_equal(r['id'], name)
        assert_equal(r['project_id'], Resizing.configure.project_id)
        assert_equal(r['content_type'], 'image/jpeg')
        assert(!r['latest_version_id'].nil?)
        assert(!r['latest_etag'].nil?)
        assert(!r['created_at'].nil?)
        assert(!r['updated_at'].nil?)
        assert(!r['height'].nil?)
        assert(!r['width'].nil?)
        assert_equal(
          r['public_id'],
          "/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/#{name}/v6Ew3HmDAYfb3NMRdLxR45i_gXMbLlGyi"
        )
      end
    end
  end
end
