# frozen_string_literal: true

require 'resizing/version'
require 'faraday'
require 'json'

module Resizing
  autoload :Client, 'resizing/client'
  autoload :Configuration, 'resizing/configuration'
  autoload :CarrierWave, 'resizing/carrier_wave'

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class APIError < Error; end

  def self.configure
    raise ConfigurationError, 'Resizing.configure is not initialized' unless defined? @configure

    @configure.dup
  end

  def self.configure=(new_value)
    new_value = Configuration.new(new_value) unless new_value.is_a? Configuration
    @configure = new_value
  end

  def self.get(name)
    raise NotImplementedError
  end

  def self.url_from_image_id(image_id, version_id = nil, transformations = [])
    Resizing.configure.generate_image_url(image_id, version_id, transformations)
  end

  def self.post(file_or_binary, options)
    client = Resizing::Client.new
    client.post file_or_binary, options
  end

  def self.put(name, file_or_binary, options)
    client = Resizing::Client.new
    client.put name, file_or_binary, options
  end

  # TODO: refactoring
  #
  # identifier:
  # public_id:  /projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/28c49144-c00d-4cb5-8619-98ce95977b9c/v1Id850..
  # identifier: ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  # project_id:           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  # image_id:                                                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  # version:                                                                                                      ^^^^^^^^^
  def self.generate_identifier
    Resizing.configure.generate_identifier
  end

  def self.separate_public_id public_id
    public_id.match('/projects/(?<project_id>[0-9a-f-]+)/upload/images/(?<image_id>[0-9a-f-]+)(/v(?<version>[^/]+))?')
  end
end
