module Resizing
  module CarrierWave
    module Storage
      class File
        include ::CarrierWave::Utilities::Uri

        def initialize(uploader)
          @uploader, @content_type = uploader, nil
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
          public_id = model.send :read_attribute, serialization_column
          resp = client.delete(public_id)
          if resp.nil?
            model.send :write_attribute, serialization_column, nil
            return
          end

          if public_id == resp['public_id']
            public_id = model.send :write_attribute, serialization_column, nil
          end

          raise NotImplementedError, "delete is not implemented"

          # # avoid a get by just using local reference
          # directory.files.new(:key => path).destroy.tap do |result|
          #   @file = nil if result
          # end
        end

        def extension
          raise NotImplementedError, 'this method is do not used. maybe'
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
          @file = nil
          file.body
        end

        def size
          file.nil? ? 0 : file.content_length
        end

        def exists?
          !!file
        end

        def store(new_file)
          if new_file.is_a?(self.class)
            # new_file.copy_to(path)
            raise NotImplementedError, "new file is required duplicating"
          else
            @content_type ||= new_file.content_type
            @response = Resizing.put(identifier, new_file.read, {content_type: @content_type})
            @public_id = @response['public_id']

            # force update column
            model_class
              .where(primary_key_name => model.send(primary_key_name))
              .update_all(serialization_column=>@public_id)

            # save new value to model class
            model.send :write_attribute, serialization_column, @public_id
          end
          true
        end

        def public_id
          @public_id
        end

        def identifier
          if public_id.present?
            public_id
          else
            @identifier = SecureRandom.uuid
          end
        end

        def filename(options = {})
          return unless file_url = url(options)
          CGI.unescape(file_url.split('?').first).gsub(/.*\/(.*?$)/, '\1')
        end

        # def copy_to(new_path)
        #   CarrierWave::Storage::Fog::File.new(@uploader, @base, new_path)
        # end

        private

        def uploader
          @uploader
        end

        def model
          @model ||= uploader.model
        end

        def model_class
          @model_class ||= model.class
        end

        def primary_key_name
          @primary_key_name ||= model_class.primary_key.to_sym
        end

        def serialization_column
          @serialization_column ||= model.send(:_mounter, uploader.mounted_as).send(:serialization_column)
        end


        ##
        # client of Resizing
        def client
          @client ||= Resizing::Client.new
        end

        ##
        # lookup file
        #
        # === Returns
        #
        # [Fog::#{provider}::File] file data from remote service
        #
        # def file
        #   @file ||= directory.files.head(path)
        # end

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


        # def store! sanitized_file
        #   puts sanitized_file.inspect
        #   client = Resizing::Client.new
        #   @store_response = client.post(sanitized_file.to_file, {content_type: sanitized_file.content_type})
        # end

        def retrieve! identifier
          raise NotImplementedError, "retrieve! #{identifier}"
        end

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
      end
    end
  end
end

