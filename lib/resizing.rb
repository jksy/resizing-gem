require "resizing/version"
require "faraday"
require "json"

module Resizing
  autoload :CarrierWave, 'resizing/carrier_wave'

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class PostError < Error; end

  #= Configuration class for Resizing client
  #--
  # usage.
  #   options = {
  #     host: 'https://www.resizing.net',
  #     project_id: '098a2a0d-0000-0000-0000-000000000000',
  #     secret_token: '4g1cshg......rbs6'
  #   }
  #   configuration = Resizing::Configuration.new(options)
  #   Resizing::Client.new(configuration)
  #++
  class Configuration
    attr_reader :host, :project_id, :secret_token, :open_timeout, :response_timeout
    DEFAULT_HOST = 'https://www.resizing.net'
    DEFAULT_OPEN_TIMEOUT = 2
    DEFAULT_RESPONSE_TIMEOUT = 10

    def initialize(*attrs)
      if attrs.length > 3
        @host = attrs.pop.dup.freeze || DEFAULT_HOST
        @project_id = attrs.pop.dup.freeze
        @secret_token = attrs.pop.dup.freeze
        @open_timeout = attrs.pop || DEFAULT_OPEN_TIMEOUT
        @response_timeout = attrs.pop || DEFAULT_RESPONSE_TIMEOUT
        return
      end

      case attr = attrs.first
      when Hash
        @host = attr[:host].dup.freeze || DEFAULT_HOST
        @project_id = attr[:project_id].dup.freeze
        @secret_token = attr[:secret_token].dup.freeze
        @open_timeout = attr[:open_timeout] || DEFAULT_OPEN_TIMEOUT
        @response_timeout = attr[:response_timeout] || DEFAULT_RESPONSE_TIMEOUT
        return
      end

      raise ConfigurationError, "need some keys like :host, :project_id, :secret_token"
    end

    def generate_auth_header
      current_timestamp = Time.now.to_i
      data = [current_timestamp, self.secret_token].join('|')
      token = Digest::SHA2.hexdigest(data)
      version = "v1"
      [version,current_timestamp,token].join(',')
    end

    def generate_image_url(image_id, version_id = nil, transforms=[])
      path = transformation_path(transforms)
      version = if version_id == nil
                  nil
                else
                  "v#{version_id}"
                end

      parts = []
      parts << image_id
      parts << version if version
      parts << path
      "#{self.host}/projects/#{self.project_id}/upload/images/#{parts.join('/')}"
    end

    def generate_public_id_from(image_id, transforms=[])
      path = transformation_path(transforms)
      "upload/images/#{image_id}/#{path}"
    end

    def transformation_path transformations
      if transformations.is_a? Hash
        transformations = [transformations]
      end

      transformation_strings = transformations.map do |transform|
        transform.slice(*TRANSFORM_OPTIONS).map {|key, value| [key, value].join('_')}.join(',')
      end.join('/')
    end

    def generate_identifier
      @image_id ||= SecureRandom.uuid

      "/projects/#{self.project_id}/upload/images/#{@image_id}"
    end
  end

  def self.configure
    unless defined? @configure
      raise ConfigurationError, "Resizing.configure is not initialized"
    end

    @configure.dup
  end

  def self.configure= new_value
    unless new_value.is_a? Configuration
      new_value = Configuration.new(new_value)
    end
    @configure = new_value
  end

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
    def initialize *attrs
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
      puts "Resizing.post(#{file_or_binary.to_s[0..30]}, #{options})"
      ensure_content_type(options)

      url = build_post_url

      body = to_io(file_or_binary)
      params = {
        image: Faraday::UploadIO.new(body, options[:content_type])
      }

      response = http_client.post(url, params) do |request|
        request.headers['X-ResizingToken'] = config.generate_auth_header
      end
      puts response.inspect

      result = handle_response(response)
      result
    end

    def put(name, file_or_binary, options)
      puts "Resizing.put(#{name}, ..., #{options})"
      ensure_content_type(options)

      url = build_put_url(name)

      body = to_io(file_or_binary)
      params = {
        image: Faraday::UploadIO.new(body, options[:content_type])
      }

      response = http_client.put(url, params) do |request|
        request.headers['X-ResizingToken'] = config.generate_auth_header
      end
      puts response.inspect

      result = handle_response(response)
      result
    end

    def delete(name)
      puts "Resizing.delete(#{name})"
      url = build_delete_url(name)

      response = http_client.delete(url) do |request|
        request.headers['X-ResizingToken'] = config.generate_auth_header
      end
      return if response.status == 404

      puts response.inspect

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
      @http_client ||= Faraday.new(:url => 'https://staging.resizing.net') do |builder|
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
        raise ArgumentError, "file_or_binary is required IO class or String"
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

  def self.get(name)
    raise NotImplementedError
  end

  TRANSFORM_OPTIONS = %i(w width h height f format c crop q quality)

  def self.url_from_image_id(image_id, version_id = nil, transformations=[])
    Resizing.configure.generate_image_url(image_id, version_id, transformations)
  end

  def self.post file_or_binary, options
    client = Resizing::Client.new
    client.post file_or_binary, options
  end

  def self.put name, file_or_binary, options
    client = Resizing::Client.new
    client.put name, file_or_binary, options
  end

  def self.generate_identifier
    name = Resizing.configure.generate_identifier
  end
end
