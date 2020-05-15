require "resizing/version"
require "faraday"
require "json"

module Resizing
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
    DEFAULT_OPEN_TIMEOUT = 2
    DEFAULT_RESPONSE_TIMEOUT = 10

    def initialize(*attrs)
      if attrs.length > 3
        @host = attrs.pop.dup.freeze
        @project_id = attrs.pop.dup.freeze
        @secret_token = attrs.pop.dup.freeze
        @open_timeout = attrs.pop || DEFAULT_OPEN_TIMEOUT
        @response_timeout = attrs.pop || DEFAULT_RESPONSE_TIMEOUT
        return
      end

      case attr = attrs.first
      when Hash
        @host = attr[:host].dup.freeze
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
      token = Digest::SHA2.hexdigest([current_timestamp, self.secret_token].join('|'))
      version = "v1"
      [version,current_timestamp,token].join(',')
    end
  end

  def self.configure
    unless defined? @configure
      @configure = nil
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
      # url = build_get_url(name)
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

    private

    def build_get_url(name)
      "#{config.host}/projects/#{config.project_id}/upload/images/#{name}"
    end

    def build_post_url
      "#{config.host}/projects/#{config.project_id}/upload/images/"
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
        StringIO.new(body)
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
        puts response.inspect
        raise PostError, response
      end
    end
  end

  def self.get(name)
    Client.new(config)
  end

  def self.url(name, transformations=[])
  end

  def self.post
  end

  def self.put(name)
  end

  def build_post_url
  end

end
