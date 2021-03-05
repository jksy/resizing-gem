# frozen_string_literal: true

require 'test_helper'

module Resizing
  module Video
    class ClientTest < Minitest::Test
      def setup
        # TODO
        # refactoring
        @configuration_template = {
          image_host: 'http://192.168.56.101:5000',
          video_host: 'http://192.168.56.101:5000',
          project_id: 'f11dfad4-2247-4220-b3b2-efeb82864a97',
          secret_token: 'xn2fkkrrp2uiragliaigkx3mwnmjis6dg35sa3kya12sq133t3xjp36s7iwamp64',
          open_timeout: 10,
          response_timeout: 20
        }
      end

      def teardown
        # NOP
      end

      def test_is_initialized
        Resizing.configure = @configuration_template

        client = Resizing::Video::Client.new
        assert(!client.config.nil?)
        assert_equal(client.config, Resizing.configure)
      end

      def test_is_initialized_with_configuration
        config = Resizing::Configuration.new(@configuration_template)
        client = Resizing::Video::Client.new(config)
        assert(!client.config.nil?)
        assert_equal(client.config, config)
      end

      def test_is_callable_build_prepare_url
        Resizing.configure = @configuration_template

        client = Resizing::Video::Client.new
        url = client.build_prepare_url
        assert_equal(url, 'http://192.168.56.101:5000/projects/f11dfad4-2247-4220-b3b2-efeb82864a97/upload/videos/prepare')
      end

      def test_is_callable_prepare
        Resizing.configure = @configuration_template

        client = Resizing::Video::Client.new
        VCR.use_cassette 'video/prepare/success', record: :once  do
          base_url = 'http://192.168.56.101:5000/projects/f11dfad4-2247-4220-b3b2-efeb82864a97/upload/videos/3a101d25-e03f-4fac-a4ee-dbe882c6139d'
          r = client.prepare
          assert_equal(r['id'], '3a101d25-e03f-4fac-a4ee-dbe882c6139d')
          assert_equal(r['project_id'], Resizing.configure.project_id)
          assert_equal(r['state'], 'initialized')
          assert_nil(r['deleted_at'])
          # assert_nil(r['source_uri']) # TODO: remove
          assert(r['s3_presigned_url'] != nil)
          assert_nil(r['converted_uri']) # TODO:remove
          assert(r['created_at'] != nil)
          assert(r['updated_at'] != nil)
          assert(r['upload_completed_url'], "#{base_url}/upload_completed")
          assert(r['self_url'], "#{base_url}.json")
          assert_nil(r['m3u8_url'])
          assert_nil(r['avc_url'])
          assert_nil(r['hevc_url'])
          assert_includes(r['thumbnail_url'], 'now-converting')
        end
      end

      def test_is_timeout_with_prepare_method
        Resizing.configure = @configuration_template.merge(project_id: 'timeout_project_id')

        client = Resizing::Video::Client.new
        assert_raises Resizing::APIError do
          client.prepare
        end
      end

      def test_is_callable_upload_complete_with_response
        Resizing.configure = @configuration_template

        client = Resizing::Video::Client.new
        r = nil
        VCR.use_cassette 'video/prepare/success', record: :once  do
          r = client.prepare
        end

        VCR.use_cassette 'video/upload_completed/success', record: :once  do
          r = client.upload_completed r
          assert_upload_completed_response r
        end
      end

      def test_is_callable_upload_complete_with_string
        Resizing.configure = @configuration_template

        client = Resizing::Video::Client.new
        r = nil
        VCR.use_cassette 'video/prepare/success', record: :once  do
          r = client.prepare
        end

        VCR.use_cassette 'video/upload_completed/success', record: :once  do
          r = client.upload_completed r['upload_completed_url']
          assert_upload_completed_response r
        end
      end

      def test_is_callable_metadata_with_response
        Resizing.configure = @configuration_template

        client = Resizing::Video::Client.new
        r = nil
        VCR.use_cassette 'video/prepare/success', record: :once  do
          r = client.prepare
        end

        completed_response = nil
        VCR.use_cassette 'video/upload_completed/success', record: :once  do
          completed_response = client.upload_completed r['upload_completed_url']
        end

        VCR.use_cassette 'video/metadata/success', record: :once  do
          r = client.metadata r
          assert_equal(completed_response, r)
        end
      end

      def assert_upload_completed_response r
        base_url = 'http://192.168.56.101:5000/projects/f11dfad4-2247-4220-b3b2-efeb82864a97/upload/videos/3a101d25-e03f-4fac-a4ee-dbe882c6139d'
        assert_equal(r['id'], '3a101d25-e03f-4fac-a4ee-dbe882c6139d')
        assert_equal(r['project_id'], Resizing.configure.project_id)
        assert_equal(r['state'], 'uploaded')
        assert_nil(r['deleted_at'])
        # assert(r['source_uri'] != nil) # TODO: remove
        assert(r['s3_presigned_url'] != nil)
        # assert_equal(r['converted_uri'], "#{base_url}/") # TODO:remove
        assert(r['created_at'] != nil)
        assert(r['updated_at'] != nil)
        assert(r['upload_completed_url'], "#{base_url}/upload_completed")
        assert(r['self_url'], "#{base_url}.json")
        assert_nil(r['m3u8_url'])
        assert_nil(r['avc_url'])
        assert_nil(r['hevc_url'])
        assert_includes(r['thumbnail_url'], 'now-converting')
        assert_equal(r['job_state']['id'], 'a586d38f-bdc3-4af2-9dbc-e0c18d2d54c5')
        assert_equal(r['job_state']['upload_video_id'], '3a101d25-e03f-4fac-a4ee-dbe882c6139d')
        assert_equal(r['job_state']['state'], 'initialized')
        assert_equal(r['job_state']['job_percent_complete'], 0)
        assert(r['job_state']['created_at'] != nil)
        assert(r['job_state']['updated_at'] != nil)
      end
    end
  end
end
