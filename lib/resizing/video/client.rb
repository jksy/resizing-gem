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

        response = handle_faraday_error do
          http_client.post(url) do |request|
            request.headers['X-ResizingToken'] = config.generate_auth_header
          end
        end
        handle_prepare_response response
      end

      def upload_completed response_or_url
        url = url_from response_or_url, 'upload_completed_url'

        response = handle_faraday_error do
          http_client.put(url) do |request|
            request.headers['X-ResizingToken'] = config.generate_auth_header
          end
        end
        handle_upload_completed_response response
      end

      def delete response_or_url
        url = url_from response_or_url, 'destroy_url'

        response = handle_faraday_error do
          http_client.put(url) do |request|
            request.headers['X-ResizingToken'] = config.generate_auth_header
          end
        end
        handle_upload_completed_response response
      end

      def metadata response_or_url
        url = url_from response_or_url, 'self_url'

        response = handle_faraday_error do
          http_client.get(url) do |request|
            request.headers['X-ResizingToken'] = config.generate_auth_header
          end
        end
        handle_metadata_response response
      end

      def build_prepare_url
        "#{config.video_host}/projects/#{config.project_id}/upload/videos/prepare"
      end

      private

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
          handle_error_response response
        end
      end

      def handle_upload_completed_response response
        raise APIError, "no response is returned" if response.nil?

        case response.status
        when HTTP_STATUS_OK
          JSON.parse(response.body)
        else
          handle_error_response response
        end
      end

      def handle_metadata_response response
        raise APIError, "no response is returned" if response.nil?

        case response.status
        when HTTP_STATUS_OK
          JSON.parse(response.body)
        else
          handle_error_response response
        end
      end

      def handle_error_response response
        result = JSON.parse(response.body) rescue {}
        err = APIError.new("invalid http status code #{response.status}")
        err.decoded_body = result
        raise err
      end
    end
  end
end
