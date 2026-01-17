# frozen_string_literal: true

module Resizing
  module CarrierWave
    module Storage
      class File
        include ::CarrierWave::Utilities::Uri

        attr_reader :public_id

        def initialize(uploader, identifier = nil)
          @uploader = uploader
          @content_type = nil
          @public_id = Resizing::PublicId.new(identifier)
          @file = nil
          @metadata = nil
        end

        def attributes
          file.attributes
        end

        def authenticated_url(_options = {})
          nil
        end

        def content_type
          @content_type || file.try(:content_type)
        end

        def delete
          # Use the identifier from constructor if available, otherwise try to get from model
          if @public_id.present?
            # Already set from constructor or retrieve
          elsif model.respond_to?(:attribute_was)
            # Try to get the value before changes (for remove! scenario)
            column_value = model.attribute_was(serialization_column) || model.send(:read_attribute,
                                                                                   serialization_column)
            @public_id = Resizing::PublicId.new(column_value)
          else
            column_value = model.send(:read_attribute, serialization_column)
            @public_id = Resizing::PublicId.new(column_value)
          end

          return if @public_id.empty? # do nothing

          # 以下、既存のコード（変更なし）
          resp = client.delete(@public_id.image_id)
          if resp['error'] == 'ActiveRecord::RecordNotFound' # 404 not found
            model.send :write_attribute, serialization_column, nil unless model.destroyed?
            return
          end

          if @public_id.image_id == resp['id']
            model.send :write_attribute, serialization_column, nil unless model.destroyed?
            return
          end

          raise APIError, "raise someone error:#{resp.inspect}"
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

        def current_path
          @current_path = model.send :read_attribute, serialization_column
        end
        alias path current_path

        def store(new_file)
          if new_file.is_a?(self.class)
            # new_file.copy_to(path)
            raise NotImplementedError, 'new file is required duplicating'
          end

          @content_type ||= if new_file.respond_to? :content_type
                              new_file.content_type
                            else
                              # guess content-type from extension
                              MIME::Types.type_for(new_file.path).first.content_type
                            end

          original_filename = new_file.try(:original_filename) || new_file.try(:filename) || new_file.try(:path)
          original_filename = ::File.basename(original_filename) if original_filename.present?

          content = if new_file.respond_to?(:to_io)
                      new_file.to_io.tap(&:rewind)
                    elsif new_file.respond_to?(:read) && new_file.respond_to?(:rewind)
                      # Pass the IO object itself, not the read result
                      new_file.rewind
                      new_file
                    else
                      new_file
                    end

          @response = Resizing.post(content, { content_type: @content_type, filename: original_filename })
          @public_id = Resizing::PublicId.new(@response['public_id'])
          @content_type = @response['content_type']

          # force update column
          # model_class
          #   .where(primary_key_name => model.send(primary_key_name))
          #   .update_all(serialization_column=>@public_id)

          # save new value to model class
          model.send :write_attribute, serialization_column, @public_id.to_s

          true
        end

        def name(_options = {})
          @public_id = PublicId.new(model.send(:read_attribute, serialization_column))
          CGI.unescape(@public_id.filename)
        end

        # def copy_to(new_path)
        #   CarrierWave::Storage::Fog::File.new(@uploader, @base, new_path)
        # end

        def retrieve(identifier)
          @public_id = Resizing::PublicId.new(identifier)
        end

        private

        attr_reader :uploader

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
          @client ||= if Resizing.configure.enable_mock
                        Resizing::MockClient.new
                      else
                        Resizing::Client.new
                      end
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

        # def retrieve_from_cache!(identifier)
        #   raise NotImplementedError,
        #     "Need to implement #retrieve_from_cache! if you want to use #{self.class.name} as a cache storage."
        # end

        # def delete_dir!(path)
        #   raise NotImplementedError,
        #     "Need to implement #delete_dir! if you want to use #{self.class.name} as a cache storage."
        # end

        # def clean_cache!(seconds)
        #   raise NotImplementedError,
        #     "Need to implement #clean_cache! if you want to use #{self.class.name} as a cache storage."
        # end
      end
    end
  end
end
