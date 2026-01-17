# frozen_string_literal: true

require 'digest/sha2'
require 'securerandom'
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
    attr_reader :image_host, :video_host, :project_id, :secret_token, :open_timeout, :response_timeout, :enable_mock
    DEFAULT_HOST = 'https://img.resizing.net'
    DEFAULT_IMAGE_HOST = 'https://img.resizing.net'
    DEFAULT_VIDEO_HOST = 'https://video.resizing.net'
    DEFAULT_OPEN_TIMEOUT = 2
    DEFAULT_RESPONSE_TIMEOUT = 10

    TRANSFORM_OPTIONS = %i[w width h height f format c crop q quality].freeze

    def initialize(*attrs)
      case attr = attrs.first
      when Hash
        raise_configiration_error if attr[:project_id].nil? || attr[:secret_token].nil?
        raise_configiration_error if attr[:host].present?

        initialize_by_hash attr
        return
      end

      raise_configiration_error
    end

    def host
      Kernel.warn '[DEPRECATED] The Configuration#host is deprecated. Use Configuration#image_host.'
      image_host
    end

    def generate_auth_header
      current_timestamp = Time.now.to_i
      data = [current_timestamp, secret_token].join('|')
      token = Digest::SHA2.hexdigest(data)
      version = 'v1'
      [version, current_timestamp, token].join(',')
    end

    def generate_image_url(image_id, version_id = nil, transforms = [])
      path = transformation_path(transforms)
      version = if version_id.nil?
                  nil
                else
                  "v#{version_id}"
                end

      parts = []
      parts << image_id
      parts << version if version
      parts << path unless path.empty?
      "#{image_host}/projects/#{project_id}/upload/images/#{parts.join('/')}"
    end

    # this method should be divided other class
    def transformation_path(transformations)
      transformations = [transformations] if transformations.is_a? Hash

      transformations.map do |transform|
        transform.slice(*TRANSFORM_OPTIONS).map { |key, value| [key, value].join('_') }.join(',')
      end.join('/')
    end

    # たぶんここにおくものではない
    # もしくはキャッシュしない
    def generate_identifier
      "/projects/#{project_id}/upload/images/#{generate_image_id}"
    end

    def generate_image_id
      ::SecureRandom.uuid
    end

    def ==(other)
      return false unless self.class == other.class

      %i[image_host video_host project_id secret_token open_timeout response_timeout].all? do |name|
        send(name) == other.send(name)
      end
    end

    private

    def raise_configiration_error
      raise ConfigurationError, 'need hash and some keys like :image_host, video_host, :project_id, :secret_token'
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def initialize_by_hash(attr)
      @image_host = attr[:image_host].dup.freeze || DEFAULT_IMAGE_HOST
      if attr[:host].present?
        if attr[:host].present?
          Kernel.warn '[DEPRECATED] The host on configration is deprecated. Use image_host, video_host'
        end
        @image_host ||= attr[:host].dup.freeze || DEFAULT_HOST # for backward compatible
      end

      @video_host = attr[:video_host].dup.freeze || DEFAULT_VIDEO_HOST
      @project_id = attr[:project_id].dup.freeze
      @secret_token = attr[:secret_token].dup.freeze
      @open_timeout = attr[:open_timeout] || DEFAULT_OPEN_TIMEOUT
      @response_timeout = attr[:response_timeout] || DEFAULT_RESPONSE_TIMEOUT
      @enable_mock = attr[:enable_mock] || false
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
