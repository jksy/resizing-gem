# frozen_string_literal: true

module Resizing
  #= Client class for Resizing
  #--
  # usage.
  #   options = {
  #     image_host: 'https://img.resizing.net',
  #     video_host: 'https://video.resizing.net',
  #     project_id: '098a2a0d-0000-0000-0000-000000000000',
  #     secret_token: '4g1cshg......rbs6'
  #   }
  #   client = Resizing::Client.new(options)
  #   file = File.open('sample.jpg', 'r')
  #   response = client.post(file, content_type: 'image/jpeg')
  #   {
  #     "id"=>"fde443bb-0b29-4be2-a04e-2da8f19716ac",
  #     "project_id"=>"098a2a0d-0000-0000-0000-000000000000",
  #     "content_type"=>"image/jpeg",
  #     "latest_version_id"=>"Ot0NL4rptk6XxQNFP2kVojn5yKG44cYH",
  #     "latest_etag"=>"\"069ec178a367089c3f0306dd716facf2\"",
  #     "created_at"=>"2020-05-17T15:02:30.548Z",
  #     "updated_at"=>"2020-05-17T15:02:30.548Z"
  #   }
  #
  #++
  class Client
    include Resizing::Constants
    include Resizing::Configurable
    include Resizing::HttpClientable

    def initialize(*attrs)
      initialize_config(*attrs)
    end

    def get(image_id)
      raise NotImplementedError
    end

    def post(file_or_binary, options = {})
      ensure_content_type(options)

      url = build_post_url

      filename = gather_filename file_or_binary, options

      body = to_io(file_or_binary)
      params = {
        image: Faraday::UploadIO.new(body, options[:content_type], filename)
      }

      response = handle_faraday_error do
        http_client.post(url, params) do |request|
          request.headers['X-ResizingToken'] = config.generate_auth_header
        end
      end

      result = handle_create_response(response)
      result
    end

    def put(image_id, file_or_binary, options)
      ensure_content_type(options)

      url = build_put_url(image_id)

      filename = gather_filename file_or_binary, options

      body = to_io(file_or_binary)
      params = {
        image: Faraday::UploadIO.new(body, options[:content_type], filename)
      }

      response = handle_faraday_error do
        http_client.put(url, params) do |request|
          request.headers['X-ResizingToken'] = config.generate_auth_header
        end
      end

      result = handle_create_response(response)
      result
    end

    def delete(image_id)
      url = build_delete_url(image_id)

      response = handle_faraday_error do
        http_client.delete(url) do |request|
          request.headers['X-ResizingToken'] = config.generate_auth_header
        end
      end

      result = handle_delete_response(response)
      result
    end

    def metadata(image_id, options = {})
      url = build_metadata_url(image_id)

      response = handle_faraday_error do
        http_client.get(url) do |request|
          request.headers['X-ResizingToken'] = config.generate_auth_header
        end
      end

      result = handle_metadata_response(response, options)
      result
    end

    private

    def build_get_url(image_id)
      "#{config.image_host}/projects/#{config.project_id}/upload/images/#{image_id}"
    end

    def build_post_url
      "#{config.image_host}/projects/#{config.project_id}/upload/images/"
    end

    def gather_filename file_or_binary, options
      filename = options[:filename]
      filename ||= file_or_binary.respond_to?(:path) ? File.basename(file_or_binary.path) : nil
    end

    def build_put_url(image_id)
      "#{config.image_host}/projects/#{config.project_id}/upload/images/#{image_id}"
    end

    def build_delete_url(image_id)
      "#{config.image_host}/projects/#{config.project_id}/upload/images/#{image_id}"
    end

    def build_metadata_url(image_id)
      "#{config.image_host}/projects/#{config.project_id}/upload/images/#{image_id}/metadata"
    end


    def to_io(data)
      return data.to_io if data.respond_to? :to_io

      case data
      when String
        StringIO.new(data)
      else
        raise ArgumentError, "file_or_binary is required IO class or String:#{data.class}"
      end
    end

    def ensure_content_type(options)
      raise ArgumentError, "need options[:content_type] for #{options.inspect}" unless options[:content_type]
    end

    def handle_create_response(response)
      raise APIError, "No response is returned" if response.nil?

      case response.status
      when HTTP_STATUS_OK, HTTP_STATUS_CREATED
        JSON.parse(response.body)
      else
        raise decode_error_from(response)
      end
    end

    def handle_delete_response(response)
      raise APIError, "No response is returned" if response.nil?

      case response.status
      when HTTP_STATUS_OK, HTTP_STATUS_NOT_FOUND
        JSON.parse(response.body)
      else
        raise decode_error_from(response)
      end
    end

    def handle_metadata_response(response, options = {})
      when_not_found = options[:when_not_found] || nil

      raise APIError, "No response is returned" if response.nil?

      case response.status
      when HTTP_STATUS_OK, HTTP_STATUS_NOT_FOUND
        JSON.parse(response.body)
      when HTTP_STATUS_NOT_FOUND
        raise decode_error_from(response) if when_not_found == :raise
        nil
      else
        raise decode_error_from(response)
      end
    end

    def decode_error_from response
      result = JSON.parse(response.body) rescue {}
      err = APIError.new(result['message'] || "invalid http status code #{response.status}")
      err.decoded_body = result
      err
    end
  end
end
