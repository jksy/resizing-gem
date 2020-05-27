require 'resizing/carrier_wave/storage/file'
require 'resizing/carrier_wave/storage/remote'

module Resizing
  module CarrierWave
    class Railtie < Rails::Railtie
      # Railtie skelton codes
      rake_tasks do
        # NOP
      end

      config.after_initialize do |app|
        # NOP
      end

      ActiveSupport.on_load(:some_class_name) do
        # NOP
      end
    end

    def self.included(base)
      base.storage Resizing::CarrierWave::Storage::Remote
      base.extend ClassMethods
    end

    def url(*args)
      return nil unless default_url.present?

      transforms = [self.transform_string]
      while version = args.pop
        transforms << self.versions[version].transform_string
      end
      "#{Resizing.configure.host}/#{default_url}/#{transforms.join('/')}"
    end

    def transform_string
      tranfrom_strings = []

      transforms = self.processors.map do |processor|
        case processor.first
        when :resize_to_fill, :resize_to_limit, :resize_to_fit
          name = processor.first.to_s.gsub /resize_to_/, ''
          {c: name, w: processor.second.first, h: processor.second.second}
        else
          raise NotImplementedError, "#{processor.first} is not supported. #{processor.inspect}"
        end.map do |key, value|
          next nil if value == nil

          "#{key}_#{value}"
        end.compact.join(',')
      end

      transforms.join('/')
    end

    def filename
      @filename ||= SecureRandom.uuid
    end

    def identifier
      # generate uuid if no identifier
      # using this identifier save name
      public_id
    end

    def public_id
      @public_id ||= Resizing.generate_identifier
    end

    def rename
      raise NotImplementedError, 'rename is not implemented'
    end

    def resize_to_limit *args
      @transform ||= []
      @transform.push(:resize_to_limit, *args)
    end

    def resize_to_fill *args
      @transform ||= []
      @transform.push(:resize_to_fill, *args)
    end

    def resize_to_fit *args
      @transform ||= []
      @transform.push(:resize_to_fit, *args)
    end

    # def process! *args
    # end

    module ClassMethods
    end

    # store_versions! is called after store!
    # Disable on Resizing, because transform the image when browser fetch the image URL
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L18
    def store_versions! *args
      # NOP
    end

    # store_versions! is called after delete
    # Disable on Resizing, because transform the image when browser fetch the image URL
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L18
    def remove_versions! *args
      # NOP
    end
  end
end
