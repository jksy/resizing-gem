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
      base.storage Resizing::CarrierWave::Storage::File
      base.extend ClassMethods
    end

    def url(*args)
      return "#{default_url}/#{self.transform_string}/#{self.versions[args.first].transform_string(*args[1..-1])}"
    end

    def transform_string
      tranfrom_strings = []

      transforms = self.processors.map do |processor|
        case processor.first
        when :resize_to_fill, :resize_to_limit, :resize_to_fit
          name = processor.first.to_s.gsub /resize_to_/, ''
          {c: name, w: processor.second.first, h: processor.second.second}
        else
          raise NotImpmemented, "#{processor.first} is not supported. #{processor.inspect}"
        end.map do |key, value|
          puts("#{key.inspect} #{value.inspect}")
          next nil if value == nil
          "#{key}=#{value}"
        end.compact.join(',')
      end

      transforms.join('/')
    end

    def default_url
      'default_url'
    end

    def filename
      raise NotImpmemented, 'file is not implemented'
    end

    def rename
      raise NotImpmemented, 'rename is not implemented'
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
    # Disable on Resizing
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L18
    def store_versions! *args
      # NOP
    end

    module Storage
      # ref.
      # https://github.com/carrierwaveuploader/carrierwave/blob/master/lib/carrierwave/storage/abstract.rb
      class File < ::CarrierWave::Storage::Abstract
        def initialize(*)
          super
        end

        def identifier
          uploader.filename
        end

        def store! sanitized_file
          puts sanitized_file.inspect
          client = Resizing::Client.new
          response = client.post(sanitized_file.to_file, {content_type: sanitized_file.content_type})
          return response['version']
        end

        def retrieve! identifier

        end

        def cache!(new_file)
          raise NotImplementedError.new("Need to implement #cache! if you want to use #{self.class.name} as a cache storage.")
        end

        def retrieve_from_cache!(identifier)
          raise NotImplementedError.new("Need to implement #retrieve_from_cache! if you want to use #{self.class.name} as a cache storage.")
        end

        def delete_dir!(path)
          raise NotImplementedError.new("Need to implement #delete_dir! if you want to use #{self.class.name} as a cache storage.")
        end

        def clean_cache!(seconds)
          raise NotImplementedError.new("Need to implement #clean_cache! if you want to use #{self.class.name} as a cache storage.")
        end

        # def default_url
        #   raise NotImpmemented, 'default_url is not implemented'
        # end

        # def url
        #   raise NotImpmemented, 'url is not implemented'
        # end
      end
    end
  end
end
