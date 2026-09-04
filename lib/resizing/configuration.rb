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
    attr_reader :image_host, :project_id, :secret_token, :open_timeout, :response_timeout, :enable_mock
    DEFAULT_HOST = 'https://img.resizing.net'
    DEFAULT_IMAGE_HOST = 'https://img.resizing.net'
    VIDEO_HOST_FALLBACK = 'https://video.resizing.net'
    private_constant :VIDEO_HOST_FALLBACK
    # 動画 API はサービス側で廃止されたため非推奨。将来のバージョンで削除する
    DEFAULT_VIDEO_HOST = VIDEO_HOST_FALLBACK
    deprecate_constant :DEFAULT_VIDEO_HOST
    DEPRECATED_VIDEO_HOST_MESSAGE = '[resizing] video_host is deprecated: ' \
                                    'the video API has been removed from Resizing and this value is no longer used. ' \
                                    'It will be deleted in a future version.'
    DEFAULT_OPEN_TIMEOUT = 2
    DEFAULT_RESPONSE_TIMEOUT = 10

    TRANSFORM_OPTIONS = %i[w width h height f format c crop q quality].freeze

    def initialize(*attrs)
      case attr = attrs.first
      when Hash
        raise_configiration_error if attr[:project_id].nil? || attr[:secret_token].nil?
        raise_deprecated_host_error unless blank_value?(attr[:host])

        initialize_by_hash attr
        return
      end

      raise_configiration_error
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

    # 動画 API の廃止により非推奨。値は保持するが利用されない
    def video_host
      warn_video_host_deprecation
      @video_host
    end

    def ==(other)
      return false unless self.class == other.class

      return false unless @video_host == other.instance_variable_get(:@video_host)

      %i[image_host project_id secret_token open_timeout response_timeout].all? do |name|
        send(name) == other.send(name)
      end
    end

    private

    # ActiveSupport の Object#present? / #blank? に依存しないための素の Ruby 実装。
    # このgemはRails外からも利用されるため、activesupportがロードされていない前提で動作する必要がある。
    def blank_value?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def raise_deprecated_host_error
      raise ConfigurationError, 'The host on configuration is deprecated. Use image_host'
    end

    def deprecated_video_host(value)
      warn_video_host_deprecation unless value.nil?
      value.dup.freeze || VIDEO_HOST_FALLBACK
    end

    def warn_video_host_deprecation
      warn DEPRECATED_VIDEO_HOST_MESSAGE
    end

    def raise_configiration_error
      raise ConfigurationError, 'need hash and some keys like :image_host, :project_id, :secret_token'
    end

    def initialize_by_hash(attr)
      @image_host = attr[:image_host].dup.freeze || DEFAULT_IMAGE_HOST
      @video_host = deprecated_video_host(attr[:video_host])
      @project_id = attr[:project_id].dup.freeze
      @secret_token = attr[:secret_token].dup.freeze
      @open_timeout = attr[:open_timeout] || DEFAULT_OPEN_TIMEOUT
      @response_timeout = attr[:response_timeout] || DEFAULT_RESPONSE_TIMEOUT
      @enable_mock = attr[:enable_mock] || false
    end
  end
end
