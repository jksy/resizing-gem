require "resizing/version"

module Resizing
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class Configuration
    attr_reader :host, :project_id, :secret_token

    def initialize(*attrs)
      if attr.length == 3
        @host = attrs[0]
        @project_id = attrs[1]
        @secret_token = attrs[2]
        return
      end

      case attr.first
      when Hash
        @host = attr[:host]
        @project_id = attr[:project_id]
        @secret_token = attr[:secret_token]
        return
      end

      raise ConfigurationError, "need some keys like :host, :project, :secret_token"
    end
  end

  class Client
    attr_reader :config
    def initialize *attr
      @config = Configuration.new(attr)
    end

    def get(name)
      "#{host}/projects/#{project_id}/upload/images/#{name}"
    end

    private

    def build_get_uri(name)
      "#{host}/projects/#{project_id}/upload/images/#{name}"
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
