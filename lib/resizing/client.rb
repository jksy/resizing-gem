# frozen_string_literal: true

module Resizing
  #= Client class for Resizing
  #--
  # usage.
  #   options = {
  #     host: 'https://www.resizing.net',
  #     project_id: '098a2a0d-0000-0000-0000-000000000000',
  #     secret_token: '4g1cshg......rbs6'
  #   }
  #   client = Resizing::Client.new(options)
  #   file = File.open('sample.jpg', 'r')
  #   response = client.post(file)
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
    # TODO
    # to use standard constants
    HTTP_STATUS_OK = 200
    HTTP_STATUS_CREATED = 201

    attr_reader :config
    def initialize(*attrs)
      @config = if attrs.first.is_a? Configuration
                  attrs.first
                elsif attrs.first.nil?
                  Resizing.configure
                else
                  Configuration.new(*attrs)
                end
    end

    def get(name)
      raise NotImplementedError
    end

    def post(file_or_binary, options = {})
      ensure_content_type(options)

      url = build_post_url

      body = to_io(file_or_binary)
      params = {
        image: Faraday::UploadIO.new(body, options[:content_type])
      }

      response = http_client.post(url, params) do |request|
        request.headers['X-ResizingToken'] = config.generate_auth_header
      end

      result = handle_response(response)
      result
    end

    def put(name, file_or_binary, options)
      ensure_content_type(options)

      url = build_put_url(name)

      body = to_io(file_or_binary)
      params = {
        image: Faraday::UploadIO.new(body, options[:content_type])
      }

      response = http_client.put(url, params) do |request|
        request.headers['X-ResizingToken'] = config.generate_auth_header
      end

      result = handle_response(response)
      result
    end

    def delete(name)
      url = build_delete_url(name)

      response = http_client.delete(url) do |request|
        request.headers['X-ResizingToken'] = config.generate_auth_header
      end
      return if response.status == 404

      result = handle_response(response)
      result
    end

    private

    def build_get_url(name)
      "#{config.host}/projects/#{config.project_id}/upload/images/#{name}"
    end

    def build_post_url
      "#{config.host}/projects/#{config.project_id}/upload/images/"
    end

    def build_put_url(name)
      "#{config.host}/projects/#{config.project_id}/upload/images/#{name}"
    end

    def build_delete_url(name)
      "#{config.host}/projects/#{config.project_id}/upload/images/#{name}"
    end

    def http_client
      @http_client ||= Faraday.new(url: config.host) do |builder|
        builder.options[:open_timeout] = config.open_timeout
        builder.options[:timeout] = config.response_timeout
        builder.request :multipart
        builder.request :url_encoded
        builder.adapter Faraday.default_adapter
      end
    end

    def to_io(data)
      case data
      when IO
        data
      when String
        StringIO.new(data)
      else
        raise ArgumentError, 'file_or_binary is required IO class or String'
      end
    end

    def ensure_content_type(options)
      raise ArgumentError, "need options[:content_type] for #{options.inspect}" unless options[:content_type]
    end

    def handle_response(response)
      case response.status
      when HTTP_STATUS_OK, HTTP_STATUS_CREATED
        JSON.parse(response.body)
      else
        raise PostError, response.body
      end
    end
  end
end
