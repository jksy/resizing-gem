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

    # ============================================================
    # 偽 HTTP クライアントを使ったリクエスト内容・レスポンス処理のテスト
    # VCR カセットでは表現しづらい (URL, ヘッダ, multipart パラメータ, 異常系ステータス) を検証する
    # ============================================================

    # Faraday::Connection の代わりに使う偽クライアント
    # 発行されたリクエスト (メソッド, URL, パラメータ, ヘッダ) を記録し、あらかじめ設定したレスポンスを返す
    class FakeHttpClient
      FakeRequest = Struct.new(:headers)
      FakeResponse = Struct.new(:status, :body)

      attr_reader :requests

      def initialize(status: 200, body: '{}', respond_with_nil: false)
        @response = respond_with_nil ? nil : FakeResponse.new(status, body)
        @requests = []
      end

      %i[post put delete get].each do |verb|
        define_method(verb) do |url, params = nil, &block|
          request = FakeRequest.new({})
          block&.call(request)
          @requests << { method: verb, url: url, params: params, headers: request.headers }
          @response
        end
      end

      def last_request
        @requests.last
      end
    end

    def client_with_fake_http(**fake_options)
      Resizing.configure = @configuration_template
      client = Resizing::Client.new
      fake = FakeHttpClient.new(**fake_options)
      client.instance_variable_set(:@http_client, fake)
      [client, fake]
    end

    def base_url
      "#{@configuration_template[:image_host]}/projects/#{@configuration_template[:project_id]}/upload/images"
    end

    def sample_path
      'test/data/images/sample1.jpg'
    end

    def not_found_body(image_id)
      %({"error":"ActiveRecord::RecordNotFound","message":"Upload::Image##{image_id} not found(no record)"})
    end

    def forbidden_body
      '{"error":"AuthenticatableSecretToken::SecretTokenError","message":"invalid token is found"}'
    end

    def test_post_sends_multipart_image_to_upload_url_with_auth_header
      client, fake = client_with_fake_http(body: '{"id":"posted"}')

      Timecop.freeze do
        result = client.post(sample_path, content_type: 'image/jpeg')

        request = fake.last_request
        assert_equal :post, request[:method]
        assert_equal "#{base_url}/", request[:url]
        assert_equal client.config.generate_auth_header, request[:headers]['X-ResizingToken']

        part = request[:params][:image]
        assert_instance_of Faraday::Multipart::FilePart, part
        assert_equal 'image/jpeg', part.content_type
        assert_equal 'sample1.jpg', part.original_filename

        assert_equal({ 'id' => 'posted' }, result)
      end
    end

    def test_post_uses_filename_option_over_path_basename
      client, fake = client_with_fake_http

      client.post(sample_path, content_type: 'image/jpeg', filename: 'renamed.jpg')

      assert_equal 'renamed.jpg', fake.last_request[:params][:image].original_filename
    end

    def test_post_accepts_io_like_object
      client, fake = client_with_fake_http
      io = StringIO.new(File.binread(sample_path))

      client.post(io, content_type: 'image/png', filename: 'from_io.png')

      part = fake.last_request[:params][:image]
      assert_same io, part.io
      assert_equal 'image/png', part.content_type
      assert_equal 'from_io.png', part.original_filename
    end

    def test_post_accepts_created_status
      client, = client_with_fake_http(status: 201, body: '{"id":"created"}')

      assert_equal({ 'id' => 'created' }, client.post(sample_path, content_type: 'image/jpeg'))
    end

    def test_post_raises_api_error_with_server_message_on_error_status
      client, = client_with_fake_http(status: 403, body: forbidden_body)

      error = assert_raises(Resizing::APIError) { client.post(sample_path, content_type: 'image/jpeg') }

      assert_equal 'invalid token is found', error.message
      assert_equal JSON.parse(forbidden_body), error.decoded_body
    end

    def test_post_raises_api_error_on_not_found
      client, = client_with_fake_http(status: 404, body: not_found_body('x'))

      assert_raises(Resizing::APIError) { client.post(sample_path, content_type: 'image/jpeg') }
    end

    def test_post_raises_api_error_with_status_code_when_body_is_not_json
      client, = client_with_fake_http(status: 502, body: '<html>Bad Gateway</html>')

      error = assert_raises(Resizing::APIError) { client.post(sample_path, content_type: 'image/jpeg') }

      assert_equal 'invalid http status code 502', error.message
      assert_equal({}, error.decoded_body)
    end

    def test_post_raises_api_error_when_response_is_nil
      client, = client_with_fake_http(respond_with_nil: true)

      error = assert_raises(Resizing::APIError) { client.post(sample_path, content_type: 'image/jpeg') }
      assert_equal 'No response is returned', error.message
    end

    def test_put_sends_multipart_image_to_image_url_with_auth_header
      client, fake = client_with_fake_http(body: '{"id":"img-1"}')

      result = client.put('img-1', sample_path, content_type: 'image/jpeg')

      request = fake.last_request
      assert_equal :put, request[:method]
      assert_equal "#{base_url}/img-1", request[:url]
      assert_match(/\Av1,\d+,[0-9a-f]{64}\z/, request[:headers]['X-ResizingToken'])
      part = request[:params][:image]
      assert_instance_of Faraday::Multipart::FilePart, part
      assert_equal 'image/jpeg', part.content_type
      assert_equal 'sample1.jpg', part.original_filename
      assert_equal({ 'id' => 'img-1' }, result)
    end

    def test_put_raises_api_error_on_error_status
      client, = client_with_fake_http(status: 403, body: forbidden_body)

      error = assert_raises(Resizing::APIError) { client.put('img-1', sample_path, content_type: 'image/jpeg') }
      assert_equal 'invalid token is found', error.message
    end

    def test_put_raises_error_with_invalid_io
      Resizing.configure = @configuration_template
      client = Resizing::Client.new

      assert_raises ArgumentError do
        client.put('image_id', 12_345, content_type: 'image/jpeg')
      end
    end

    def test_delete_sends_delete_request_to_image_url_with_auth_header
      client, fake = client_with_fake_http(body: '{"id":"img-1"}')

      result = client.delete('img-1')

      request = fake.last_request
      assert_equal :delete, request[:method]
      assert_equal "#{base_url}/img-1", request[:url]
      assert_match(/\Av1,\d+,[0-9a-f]{64}\z/, request[:headers]['X-ResizingToken'])
      assert_equal({ 'id' => 'img-1' }, result)
    end

    def test_delete_returns_error_body_without_raising_on_not_found
      client, = client_with_fake_http(status: 404, body: not_found_body('img-1'))

      result = client.delete('img-1')

      assert_equal 'ActiveRecord::RecordNotFound', result['error']
    end

    def test_delete_raises_api_error_on_other_error_status
      client, = client_with_fake_http(status: 403, body: forbidden_body)

      error = assert_raises(Resizing::APIError) { client.delete('img-1') }
      assert_equal 'invalid token is found', error.message
    end

    def test_delete_raises_api_error_when_response_is_nil
      client, = client_with_fake_http(respond_with_nil: true)

      assert_raises(Resizing::APIError) { client.delete('img-1') }
    end

    def test_metadata_sends_get_request_to_metadata_url_with_auth_header
      client, fake = client_with_fake_http(body: '{"id":"img-1","width":100}')

      result = client.metadata('img-1')

      request = fake.last_request
      assert_equal :get, request[:method]
      assert_equal "#{base_url}/img-1/metadata", request[:url]
      assert_match(/\Av1,\d+,[0-9a-f]{64}\z/, request[:headers]['X-ResizingToken'])
      assert_equal({ 'id' => 'img-1', 'width' => 100 }, result)
    end

    def test_metadata_returns_error_body_without_raising_on_not_found_by_default
      client, = client_with_fake_http(status: 404, body: not_found_body('img-1'))

      result = client.metadata('img-1')

      assert_equal 'ActiveRecord::RecordNotFound', result['error']
    end

    def test_metadata_raises_api_error_on_not_found_when_requested
      client, = client_with_fake_http(status: 404, body: not_found_body('img-1'))

      error = assert_raises(Resizing::APIError) { client.metadata('img-1', when_not_found: :raise) }

      assert_equal 'Upload::Image#img-1 not found(no record)', error.message
      assert_equal 'ActiveRecord::RecordNotFound', error.decoded_body['error']
    end

    def test_metadata_raises_api_error_on_other_error_status
      client, = client_with_fake_http(status: 500, body: 'Internal Server Error')

      error = assert_raises(Resizing::APIError) { client.metadata('img-1') }
      assert_equal 'invalid http status code 500', error.message
    end

    def test_metadata_raises_api_error_when_response_is_nil
      client, = client_with_fake_http(respond_with_nil: true)

      assert_raises(Resizing::APIError) { client.metadata('img-1') }
    end

    # ============================================================
    # VCR カセットを使った delete / timeout のテスト
    # ============================================================

    def test_is_deletable
      # client/delete.yml は別プロジェクト ID で記録されている
      Resizing.configure = @configuration_template.merge(project_id: '098a2a0d-c387-4135-a071-1254d6d7e70a')
      client = Resizing::Client.new
      image_id = '28c49144-c00d-4cb5-8619-98ce95977b9c'

      VCR.use_cassette 'client/delete', record: :none do
        r = client.delete(image_id)

        assert_equal image_id, r['id']
        assert_equal '098a2a0d-c387-4135-a071-1254d6d7e70a', r['project_id']
        assert_equal(
          "/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/#{image_id}/v1Id850__tqNsnoGWWUibtIBZ5NgjV45M",
          r['public_id']
        )
      end
    end

    def test_is_timeout_with_delete_method
      Resizing.configure = @configuration_template.merge(project_id: 'timeout_project_id')
      client = Resizing::Client.new

      assert_raises Resizing::APIError do
        client.delete('some_image_id')
      end
    end

    def test_is_timeout_with_metadata_method
      Resizing.configure = @configuration_template.merge(project_id: 'timeout_project_id')
      client = Resizing::Client.new

      assert_raises Resizing::APIError do
        client.metadata('some_image_id')
      end
    end

    # ============================================================
    # 設定の受け渡し
    # ============================================================

    def test_is_initialized_with_hash
      client = Resizing::Client.new(@configuration_template)

      assert_equal Resizing::Configuration.new(@configuration_template), client.config
    end

    def test_each_client_instance_keeps_its_own_configuration
      Resizing.configure = @configuration_template
      other = Resizing::Client.new(@configuration_template.merge(project_id: 'other-project'))

      assert_equal 'other-project', other.config.project_id
      assert_equal @configuration_template[:project_id], Resizing::Client.new.config.project_id
    end

    def test_client_uses_configuration_at_instantiation
      Resizing.configure = @configuration_template
      client = Resizing::Client.new

      # インスタンス生成後にグローバル設定を差し替えても既存クライアントには影響しない
      Resizing.configure = @configuration_template.merge(project_id: 'replaced-project')

      assert_equal @configuration_template[:project_id], client.config.project_id
    end
  end
end
