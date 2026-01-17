# frozen_string_literal: true

require 'resizing/carrier_wave/storage/file'
require 'resizing/carrier_wave/storage/remote'

module Resizing
  # rubocop:disable Metrics/ModuleLength
  module CarrierWave
    class Railtie < ::Rails::Railtie
      # Railtie skelton codes
      rake_tasks do
        # NOP
      end

      config.after_initialize do |app|
        # NOP
      end

      ActiveSupport.on_load(:active_record) do
        # NOP
      end
    end

    def self.included(base)
      base.storage Resizing::CarrierWave::Storage::Remote
      base.extend ClassMethods
    end

    def initialize(*args)
      @requested_format = nil
      @default_format = nil
      super
    end

    def file
      file_identifier = identifier || read_column

      return nil if file_identifier.blank?

      @file ||= Resizing::CarrierWave::Storage::File.new(self)
      @file.retrieve(file_identifier)
      @file
    end

    def url(*args)
      return default_url unless read_column.present?

      transforms = args.map do |version|
        version = version.intern
        raise "No version is found: #{version}, #{versions.keys} are exists." unless versions.key? version

        versions[version].transform_string
      end.compact

      "#{build_url}/#{transforms.join('/')}"
    end

    def read_column
      model.read_attribute(serialization_column)
    end

    def build_url
      "#{Resizing.configure.image_host}#{model.read_attribute(serialization_column)}"
    end

    # need override this. if you want to return some url when target_column is nil
    def default_url
      nil
    end

    def transform_string
      transforms = processors.map do |processor|
        transform_string_from processor
      end

      transforms.join('/')
    end

    def rename
      raise NotImplementedError, 'rename is not implemented'
    end

    def resize_to_limit(*args)
      @transform ||= []
      @transform.push(:resize_to_limit, *args)
    end

    def resize_to_fill(*args)
      @transform ||= []
      @transform.push(:resize_to_fill, *args)
    end

    def resize_to_fit(*args)
      @transform ||= []
      @transform.push(:resize_to_fit, *args)
    end

    def cache!(new_file)
      return if new_file.nil?

      file = storage.store!(new_file)
      # do not assign @cache_id, bacause resizing do not support cache
      # save to resizing directly
      # @cache_id = file.public_id

      @filename = file.public_id.to_s
      @file = file
    end

    def filename
      read_column
    end

    def serialization_column
      model.send(:_mounter, mounted_as).send(:serialization_column)
    end

    # store_versions! is called after store!
    # Disable on Resizing, because transform the image when browser fetch the image URL
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L18
    def store_versions!(*args)
      # NOP
    end

    # store_versions! is called after delete
    # Disable on Resizing, because transform the image when browser fetch the image URL
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L18
    def remove_versions!(*args)
      # NOP
    end

    def requested_format
      # TODO
      # The request with uploading format parameter is not working on the Resizing until 2020/09/25
      @requested_format
    end

    def default_format
      @default_format
    end

    def format
      requested_format || default_format
    end

    module ClassMethods
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def transform_string_from(processor)
      action = processor.first
      value = processor.second

      case action
      when :resize_to_fill, :resize_to_limit, :resize_to_fit
        name = action.to_s.gsub(/resize_to_/, '')
        { c: name, w: value.first, h: value.second }
      when :transformation
        result = {}
        result[:q] = value[:quality] if value[:quality]
        result[:f] = value[:fetch_format] if value[:fetch_format]
        result[:f] = value[:format] if value[:format]
        result
      else
        raise NotImplementedError, "#{action} is not supported. #{processor.inspect}"
      end.map do |key, value|
        next nil if value.nil?

        "#{key}_#{value}"
      end.compact.join(',')
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  end
  # rubocop:enable Metrics/ModuleLength
end
