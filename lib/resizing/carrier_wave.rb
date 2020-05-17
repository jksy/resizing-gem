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
      base.storage Resizing::CarrierWave::Storage
      base.extends ClassMethods
    end

    def url(*args)
      raise NotImpmemented, 'url is not implemented'
    end

    def filename
      raise NotImpmemented, 'file is not implemented'
    end

    def rename
      raise NotImpmemented, 'rename is not implemented'
    end


    module Storage
      # ref.
      # https://github.com/carrierwaveuploader/carrierwave/blob/master/lib/carrierwave/storage/fog.rb
      def default_url
        raise NotImpmemented, 'default_url is not implemented'
      end

      def url
        raise NotImpmemented, 'url is not implemented'
      end

      def store(new_file)
        raise NotImpmemented, 'store is not implemented'
      end

      def public_url
        raise NotImpmemented, 'public_url is not implemented'
      end

      def url
        raise NotImpmemented, 'url is not implemented'
      end
    end
  end
end
