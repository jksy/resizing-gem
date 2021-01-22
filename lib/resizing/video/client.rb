# frozen_string_literal: true

module Resizing
  module Video
    class Client
      include Resizing::Constants
      include Resizing::Configurable
      include Resizing::HttpClientable

      def initialize(*attrs)
        initialize_config(*attrs)
      end

      def prepare
        url = build_prepare_url

        response = http_client.post(url) do |request|
          request.headers['X-ResizingToken'] = config.generate_auth_header
        end
        handle_prepare_response response
      rescue Faraday::TimeoutError => e
        handle_timeout_error e
      end

      def upload_completed response_or_url
        url = url_from response_or_url, 'upload_completed_url'

        response = http_client.put(url) do |request|
          request.headers['X-ResizingToken'] = config.generate_auth_header
        end
        handle_upload_completed_response response
      end

      def metadata response_or_url
        url = url_from response_or_url, 'self_url'

        response = http_client.get(url) do |request|
          request.headers['X-ResizingToken'] = config.generate_auth_header
        end
        handle_metadata_response response
      rescue Faraday::TimeoutError => e
        handle_timeout_error e
      end

      private

      def build_prepare_url
        "#{config.host}/projects/#{config.project_id}/upload/videos/prepare"
      end

      def url_from response_or_url, name
        if response_or_url.kind_of? String
          response_or_url
        elsif response_or_url.kind_of? Hash
          response_or_url[name.to_s] || response_or_url[name.intern]
        else
          raise ArgumentError, "upload_completed is require Hash or String"
        end
      end

      def handle_prepare_response response
        raise APIError, "no response is returned" if response.nil?

        case response.status
        when HTTP_STATUS_OK, HTTP_STATUS_CREATED
          JSON.parse(response.body)
        else
          result = JSON.parse(response.body) rescue {}
          err = APIError.new("invalid http status code #{response.status}")
          err.decoded_body = result
          raise err
        end
      end

      def handle_upload_completed_response response
        raise APIError, "no response is returned" if response.nil?

        case response.status
        when HTTP_STATUS_OK
          JSON.parse(response.body)
        else
          result = JSON.parse(response.body) rescue {}
          err = APIError.new("invalid http status code #{response.status}")
          err.decoded_body = result
          raise err
        end
      end

      def handle_metadata_response response
        raise APIError, "no response is returned" if response.nil?

        case response.status
        when HTTP_STATUS_OK
          JSON.parse(response.body)
        else
          result = JSON.parse(response.body) rescue {}
          err = APIError.new("invalid http status code #{response.status}")
          err.decoded_body = result
          raise err
        end
      end

      def handle_timeout_error error
        raise APIError.new("TimeoutError: #{error.inspect}")
      end
    end
  end
end
