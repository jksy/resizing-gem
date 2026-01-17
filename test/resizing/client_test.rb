# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ClientTest < Minitest::Test
    def setup
      @configuration_template = {
        image_host: 'http://192.168.56.101:5000',
        video_host: 'http://192.168.56.101:5000',
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

    def test_is_postable_with_filename
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/post', record: :once do
        r = client.post('test/data/images/sample1.jpg', content_type: 'image/jpeg')
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

    def test_is_unpostable_with_filename
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/post', record: :once do
        assert_raises ArgumentError do
          client.post('file_is_not_exists', content_type: 'image/jpeg')
        end
      end
    end

    def test_is_postable_with_file
      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/post', record: :once do
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

    def test_is_timeout_with_post_method
      Resizing.configure = @configuration_template.merge(project_id: 'timeout_project_id')

      client = Resizing::Client.new
      f = File.open('test/data/images/sample1.jpg', 'r')
      assert_raises Resizing::APIError do
        client.post(f, content_type: 'image/jpeg')
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

    def test_is_timeout_with_put_method
      Resizing.configure = @configuration_template.merge(project_id: 'timeout_project_id')

      client = Resizing::Client.new
      name = 'AWEaewfAreaweFAFASfwe'
      f = File.open('test/data/images/sample1.jpg', 'r')

      assert_raises Resizing::APIError do
        _r = client.put(name, f, content_type: 'image/jpeg')
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
        assert_equal response, { 'error' => 'Magick::ImageMagickError', 'message' => 'invalid image format found' }
      end
    end

    def test_get_the_metadata
      # TODO

      Resizing.configure = @configuration_template

      client = Resizing::Client.new
      VCR.use_cassette 'client/metadata', record: :once do
        name = '87263920-2081-498e-a107-9625f4fde01b'
        r = client.metadata(name)
        # r.body
        # {
        #   "id":"87263920-2081-498e-a107-9625f4fde01b",
        #   "project_id":"e06e710d-f026-4dcf-b2c0-eab0de8bb83f",
        #   "content_type":"image/jpeg",
        #   "latest_version_id":"Hg9VFvdI6HRzLFbV495VdwVmHIspLRCo",
        #   "latest_etag":"\"5766f95a7f28e6a53dd6fd179bf03a32\"",
        #   "size":848590,
        #   "created_at":"2020-10-11T05:02:25.912Z",
        #   "updated_at":"2020-10-11T05:02:25.912Z",
        #   "filename":"sample1.jpg",
        #   "width":4032,
        #   "height":3016,
        #   "format":"jpeg",
        #   "version":"Hg9VFvdI6HRzLFbV495VdwVmHIspLRCo",
        #   "public_id":"/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/87263920-2081-498e-a107-9625f4fde01b/vHg9VFvdI6HRzLFbV495VdwVmHIspLRCo"
        # }

        assert_equal(r['id'], name)
        assert_equal(r['project_id'], Resizing.configure.project_id)
        assert_equal(r['content_type'], 'image/jpeg')
        assert_equal(r['latest_version_id'], 'Hg9VFvdI6HRzLFbV495VdwVmHIspLRCo')
        assert_equal(r['latest_etag'], '"5766f95a7f28e6a53dd6fd179bf03a32"')
        assert_equal(r['created_at'], '2020-10-11T05:02:25.912Z')
        assert_equal(r['updated_at'], '2020-10-11T05:02:25.912Z')
        assert_equal(r['width'], 4032)
        assert_equal(r['height'], 3016)
        assert_equal(r['format'], 'jpeg')
        assert_equal(r['version'], 'Hg9VFvdI6HRzLFbV495VdwVmHIspLRCo')
        assert_equal(
          r['public_id'],
          '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/87263920-2081-498e-a107-9625f4fde01b/vHg9VFvdI6HRzLFbV495VdwVmHIspLRCo'
        )
      end
    end

    def test_get_raises_not_implemented_error
      Resizing.configure = @configuration_template
      client = Resizing::Client.new

      assert_raises NotImplementedError do
        client.get('some_image_id')
      end
    end

    def test_post_raises_error_without_content_type
      Resizing.configure = @configuration_template
      client = Resizing::Client.new

      assert_raises ArgumentError do
        client.post('test/data/images/sample1.jpg', {})
      end
    end

    def test_post_raises_error_with_invalid_io
      Resizing.configure = @configuration_template
      client = Resizing::Client.new

      assert_raises ArgumentError do
        client.post(12_345, content_type: 'image/jpeg')
      end
    end

    def test_put_raises_error_without_content_type
      Resizing.configure = @configuration_template
      client = Resizing::Client.new

      assert_raises ArgumentError do
        client.put('image_id', 'test/data/images/sample1.jpg', {})
      end
    end
  end
end
