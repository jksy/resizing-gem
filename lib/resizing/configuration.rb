require 'digest/sha2'
module Resizing
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

    TRANSFORM_OPTIONS = %i(w width h height f format c crop q quality)

    def initialize(*attrs)
      case attr = attrs.first
      when Hash
        if attr[:project_id] == nil || attr[:secret_token] == nil
          raise_configiration_error
        end
        @host = attr[:host].dup.freeze || DEFAULT_HOST
        @project_id = attr[:project_id].dup.freeze
        @secret_token = attr[:secret_token].dup.freeze
        @open_timeout = attr[:open_timeout] || DEFAULT_OPEN_TIMEOUT
        @response_timeout = attr[:response_timeout] || DEFAULT_RESPONSE_TIMEOUT
        return
      end

      raise_configiration_error
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

      transformations.map do |transform|
        transform.slice(*TRANSFORM_OPTIONS).map {|key, value| [key, value].join('_')}.join(',')
      end.join('/')
    end

    def generate_identifier
      @image_id ||= SecureRandom.uuid

      "/projects/#{self.project_id}/upload/images/#{@image_id}"
    end

    private

    def raise_configiration_error
      raise ConfigurationError, "need hash and some keys like :host, :project_id, :secret_token"
    end
  end
end
