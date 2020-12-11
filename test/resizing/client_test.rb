# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ClientTest < Minitest::Test
    def setup
      # NOP
      @configuration_template = {
        host: 'http://192.168.56.101:5000',
        project_id: 'e06e710d-f026-4dcf-b2c0-eab0de8bb83f',
        secret_token: 'ewbym2r1pk49x1d2lxdbiiavnqp25j2kh00hsg3koy0ppm620x5mhlmgl3rq5ci8',
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
        assert_equal(r['id'], '87263920-2081-498e-a107-9625f4fde01b')
        assert_equal(r['project_id'], Resizing.configure.project_id)
        assert_equal(r['content_type'], 'image/jpeg')
        assert(!r['latest_version_id'].nil?)
        assert(!r['latest_etag'].nil?)
        assert(!r['created_at'].nil?)
        assert(!r['updated_at'].nil?)
        assert_equal(r['public_id'], '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/87263920-2081-498e-a107-9625f4fde01b/vHg9VFvdI6HRzLFbV495VdwVmHIspLRCo')
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
          "/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/#{name}/vfztekhN_WoeXo8ZkCZ4i5jcQvmPpZewR"
        )
      end
    end

    def test_raise_error
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/error', record: :once do
        f = File.open('test/data/images/empty_file.jpg', 'r')
        assert_raises Resizing::APIError do
          client.post(f, content_type: 'image/jpeg')
        end
      end
    end

    def test_handleable_response_body_from_resizing
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/error', record: :once do
        f = File.open('test/data/images/empty_file.jpg', 'r')

        response = nil

        begin
          client.post(f, content_type: 'image/jpeg')
        rescue Resizing::APIError => e
          response = e.decoded_body
        end
        assert_equal response, {"error"=>"Magick::ImageMagickError", "message"=>"invalid image format found"}
      end
    end

    def test_get_the_metadata
      # TODO

      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/metadata', record: :once do
        name = '87263920-2081-498e-a107-9625f4fde01b'
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
          "/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/87263920-2081-498e-a107-9625f4fde01b/vHg9VFvdI6HRzLFbV495VdwVmHIspLRCo"
        )
      end
    end
  end
end
