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

    # def default_url
    #   @public_id ||= self.model.attributes[self.mounted_as.to_s]
    #   @public_id
    # end

    def filename
      @filename ||= SecureRandom.uuid
      # binding.pry
      # SecureRandom.uuid
      # self.sanitized_file.file.name
      # # self.sanitized_file.to_file, {content_type: sanitized_file.content_type})
      # raise NotImplementedError, "filename is not implemented:#{self.inspect}"
    end

    def identifier
      # generate uuid if no identifier
      # using this identifier save name
      public_id
    end

    def public_id
      binding.pry
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

    module Storage
      # ref.
      # https://github.com/carrierwaveuploader/carrierwave/blob/master/lib/carrierwave/storage/abstract.rb
      class Remote < ::CarrierWave::Storage::Abstract
        def store!(file)
          f = Resizing::CarrierWave::Storage::File.new(uploader, self, uploader.store_path)
          f.store(file)
          @filename = f.public_url
          f
        end

        def retrieve!(identifier)
          Resizing::CarrierWave::Storage::File.new(uploader, self, uploader.store_path(identifier))
        end

        def cache!(new_file)
          f = Resizing::CarrierWave::Storage::File.new(uploader, self, uploader.cache_path)
          f.store(new_file)
          f
        end

        def retrieve_from_cache!(identifier)
          Resizing::CarrierWave::Storage::File..new(uploader, self, uploader.cache_path(identifier))
        end

        def delete_dir!(path)
          # do nothing, because there's no such things as 'empty directory'
        end

        def clean_cache!(seconds)
          # do nothing
          #
          # connection.directories.new(
          #   :key    => uploader.fog_directory,
          #   :public => uploader.fog_public
          # ).files.all(:prefix => uploader.cache_dir).each do |file|
          #   # generate_cache_id returns key formated TIMEINT-PID(-COUNTER)-RND
          #   time = file.key.scan(/(\d+)-\d+-\d+(?:-\d+)?/).first.map { |t| t.to_i }
          #   time = Time.at(*time)
          #   file.destroy if time < (Time.now.utc - seconds)
          # end
        end
      end

      class File
        include ::CarrierWave::Utilities::Uri

        attr_reader :path

        def initialize(uploader, base, path)
          @uploader, @base, @path, @content_type = uploader, base, path, nil
        end

        def attributes
          file.attributes
        end

        def authenticated_url(options = {})
          nil
        end

        def content_type
          @content_type || file.try(:content_type)
        end

        def content_type=(new_content_type)
          @content_type = new_content_type
        end

        def delete
          column = uploader.model.send(:_mounter, uploader.mounted_as).send(:serialization_column)
          public_id = uploader.model.send :read_attribute, column
          puts "delete => #{public_id}"
          resp = connection.delete(public_id)
          if resp.nil?
            puts "already deleted"
            uploader.model.send :write_attribute, column, nil
            return
          end
          puts resp

          if public_id == resp['public_id']
            public_id = uploader.model.send :write_attribute, column, nil
          end

          self.model
          puts self.inspect
          p caller()
          raise NotImplementedError, "delete is not implemented"

          # # avoid a get by just using local reference
          # directory.files.new(:key => path).destroy.tap do |result|
          #   @file = nil if result
          # end
        end

        def extension
          path_elements = path.split('.')
          path_elements.last if path_elements.size > 1
        end

        ##
        # Read content of file from service
        #
        # === Returns
        #
        # [String] contents of file
        def read
          file_body = file.body

          return if file_body.nil?
          return file_body unless file_body.is_a?(::File)

          # Fog::Storage::XXX::File#body could return the source file which was upoloaded to the remote server.
          read_source_file(file_body) if ::File.exist?(file_body.path)

          # If the source file doesn't exist, the remote content is read
          @file = nil # rubocop:disable Gitlab/ModuleWithInstanceVariables
          file.body
        end

        def size
          file.nil? ? 0 : file.content_length
        end

        def exists?
          !!file
        end

        def store(new_file)
          puts "store(#{new_file})"
          if new_file.is_a?(self.class)
            # new_file.copy_to(path)
            raise NotImplementedError, "new file is required duplicating"
          else
            @content_type ||= new_file.content_type
            @response = Resizing.put(identifier, new_file.read, {content_type: @content_type})

            @public_id = @response['public_id']

            # write public_id to mounted column
            column = uploader.model.send(:_mounter, uploader.mounted_as).send(:serialization_column)
            model_klass = uploader.model.class
            primary_key = model_klass.primary_key.to_sym

            # force update column
            model_klass.where(primary_key => uploader.model.send(primary_key)).update_all(column=>@public_id)
            # save new value to model class
            uploader.model.send :write_attribute, column, @public_id

            # fog_file = new_file.to_file
            # @content_type ||= new_file.content_type
            # @file = directory.files.create({
            #   :body         => fog_file ? fog_file : new_file.read,
            #   :content_type => @content_type,
            #   :key          => path,
            #   :public       => @uploader.fog_public
            # }.merge(@uploader.fog_attributes))
            # fog_file.close if fog_file && !fog_file.closed?
          end
          true
        end

        def uploader
          @uploader
        end

        def public_url
          'public_url'
          # encoded_path = encode_path(path)
          # if host = @uploader.asset_host
          #   if host.respond_to? :call
          #     "#{host.call(self)}/#{encoded_path}"
          #   else
          #     "#{host}/#{encoded_path}"
          #   end
          # else
          #   # AWS/Google optimized for speed over correctness
          #   case fog_provider
          #   when 'AWS'
          #     # check if some endpoint is set in fog_credentials
          #     if @uploader.fog_credentials.has_key?(:endpoint)
          #       "#{@uploader.fog_credentials[:endpoint]}/#{@uploader.fog_directory}/#{encoded_path}"
          #     else
          #       protocol = @uploader.fog_use_ssl_for_aws ? "https" : "http"

          #       subdomain_regex = /^(?:[a-z]|\d(?!\d{0,2}(?:\d{1,3}){3}$))(?:[a-z0-9\.]|(?![\-])|\-(?![\.])){1,61}[a-z0-9]$/
          #       valid_subdomain = @uploader.fog_directory.to_s =~ subdomain_regex && !(protocol == 'https' && @uploader.fog_directory =~ /\./)

          #       # if directory is a valid subdomain, use that style for access
          #       if valid_subdomain
          #         s3_subdomain = @uploader.fog_aws_accelerate ? "s3-accelerate" : "s3"
          #         "#{protocol}://#{@uploader.fog_directory}.#{s3_subdomain}.amazonaws.com/#{encoded_path}"
          #       else
          #         # directory is not a valid subdomain, so use path style for access
          #         "#{protocol}://s3.amazonaws.com/#{@uploader.fog_directory}/#{encoded_path}"
          #       end
          #     end
          #   when 'Google'
          #     # https://cloud.google.com/storage/docs/access-public-data
          #     "https://storage.googleapis.com/#{@uploader.fog_directory}/#{encoded_path}"
          #   else
          #     # avoid a get by just using local reference
          #     directory.files.new(:key => path).public_url
          #   end
          # end
        end

        ##
        # Return url to file, if avaliable
        #
        # === Returns
        #
        # [String] url
        #   or
        # [NilClass] no url available
        #
        def url(options = {})
          public_url
          # if !@uploader.fog_public
          #   authenticated_url(options)
          # else
          #   public_url
          # end
        end

        ##
        # Return file name, if available
        #
        # === Returns
        #
        # [String] file name
        #   or
        # [NilClass] no file name available
        #
        def filename(options = {})
          return unless file_url = url(options)
          CGI.unescape(file_url.split('?').first).gsub(/.*\/(.*?$)/, '\1')
        end

        ##
        # Creates a copy of this file and returns it.
        #
        # === Parameters
        #
        # [new_path (String)] The path where the file should be copied to.
        #
        # === Returns
        #
        # @return [CarrierWave::Storage::Fog::File] the location where the file will be stored.
        #
        def copy_to(new_path)
          # connection.copy_object(@uploader.fog_directory, file.key, @uploader.fog_directory, new_path, acl_header)
          CarrierWave::Storage::Fog::File.new(@uploader, @base, new_path)
        end

        private

        ##
        # connection to service
        #
        # === Returns
        #
        # [Fog::#{provider}::Storage] connection to service
        #
        def connection
          @connection ||= Resizing::Client.new
          # @base.connection
        end

        ##
        # local reference to directory containing file
        #
        # === Returns
        #
        # [Fog::#{provider}::Directory] containing directory
        #
        def directory
          raise NotImplementedError, "directory is not implemementedle. #{self.inspect}"
          @directory ||= begin
            connection.directories.new(
              :key    => @uploader.fog_directory,
              :public => @uploader.fog_public
            )
          end
        end

        ##
        # lookup file
        #
        # === Returns
        #
        # [Fog::#{provider}::File] file data from remote service
        #
        def file
          @file ||= directory.files.head(path)
        end

        def acl_header
          if fog_provider == 'AWS'
            { 'x-amz-acl' => @uploader.fog_public ? 'public-read' : 'private' }
          else
            {}
          end
        end

        def fog_provider
          @uploader.fog_credentials[:provider].to_s
        end

        def read_source_file(file_body)
          return unless ::File.exist?(file_body.path)

          begin
            file_body = ::File.open(file_body.path) if file_body.closed? # Reopen if it's already closed
            file_body.read
          ensure
            file_body.close
          end
        end

        def url_options_supported?(local_file)
          parameters = local_file.method(:url).parameters
          parameters.count == 2 && parameters[1].include?(:options)
        end

        # # def initialize(*)
        # #   super
        # #   @store_response = nil
        # # end

        def identifier
          return SecureRandom.uuid
          uploader.filename
        end

        # def store! sanitized_file
        #   puts sanitized_file.inspect
        #   client = Resizing::Client.new
        #   @store_response = client.post(sanitized_file.to_file, {content_type: sanitized_file.content_type})
        # end

        # def retrieve! identifier
        #   binding.pry
        #   raise NotImplementedError, "retrieve! #{identifier}"
        # end

        # def cache!(new_file)
        #   raise NotImplementedError, "Need to implement #cache! if you want to use #{self.class.name} as a cache storage."
        # end

        # def retrieve_from_cache!(identifier)
        #   raise NotImplementedError, "Need to implement #retrieve_from_cache! if you want to use #{self.class.name} as a cache storage."
        # end

        # def delete_dir!(path)
        #   raise NotImplementedError "Need to implement #delete_dir! if you want to use #{self.class.name} as a cache storage."
        # end

        # def clean_cache!(seconds)
        #   raise NotImplementedError "Need to implement #clean_cache! if you want to use #{self.class.name} as a cache storage."
        # end

        # # def default_url
        # #   raise NotImpmemented, 'default_url is not implemented'
        # # end

        # # def url
        # #   raise NotImpmemented, 'url is not implemented'
        # # end
      end
    end
  end
end
