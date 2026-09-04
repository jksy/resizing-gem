# frozen_string_literal: true

module Resizing
  module CarrierWave
    module Storage
      # rubocop:disable Metrics/ClassLength
      class File
        include ::CarrierWave::Utilities::Uri

        # Fallback content type used when the type cannot be determined from the file name.
        DEFAULT_CONTENT_TYPE = 'application/octet-stream'

        attr_reader :public_id

        def initialize(uploader, identifier = nil)
          @uploader = uploader
          @content_type = nil
          @public_id = Resizing::PublicId.new(identifier)
          @metadata = nil
          @metadata_fetched = false
        end

        # Metadata of the stored image, as returned by the Resizing metadata API.
        #
        # === Returns
        #
        # [Hash, nil] metadata hash, or nil when the image is unknown/unreachable
        def attributes
          metadata
        end

        def authenticated_url(_options = {})
          nil
        end

        # NOTE: Called through CarrierWave's Uploader::Proxy#content_type, so it must not
        # raise. Falls back to the metadata API when the content type is not known locally
        # (e.g. the model was reloaded from the DB), and returns nil if it cannot be fetched.
        def content_type
          @content_type ||= metadata && metadata['content_type']
        end

        # rubocop:disable Metrics/AbcSize
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

          return if @public_id.empty?

          resp = client.delete(@public_id.image_id)

          # NOTE: 削除時のカラムクリアは以下の理由で必要:
          # - 画像更新時: 古い画像IDと新しい画像IDが異なるため、古い画像削除時に新しいIDを消さないようにする
          # - 明示的なremove!時: カラムをnilにする必要がある
          # - clear_column_if_current_imageは削除される画像IDと現在のカラム値を比較して判断
          if resp['error'] == 'ActiveRecord::RecordNotFound' # 404 not found
            clear_column_if_current_image
            return
          end

          if @public_id.image_id == resp['id']
            clear_column_if_current_image
            return
          end

          raise APIError, "raise someone error:#{resp.inspect}"
        end
        # rubocop:enable Metrics/AbcSize

        def extension
          raise NotImplementedError, 'this method is do not used. maybe'
        end

        ##
        # Read content of file from service
        #
        # NOTE: Resizing keeps no local copy of the stored image and this gem has no API to
        # download the binary (Resizing::Client#get is not implemented either), so reading the
        # content would require a new download API. It is not called by the regular CarrierWave
        # flow (only through Uploader::Proxy#read, i.e. explicitly by the application), so it
        # raises instead of silently returning nil.
        def read
          raise NotImplementedError, 'Resizing does not support reading the stored image content'
        end

        # NOTE: Called through CarrierWave's Uploader::Proxy#size, so it must not raise.
        # The size is only known to the Resizing service, so it comes from the metadata API.
        # Returns 0 when it cannot be fetched, following Uploader::Proxy#size, which itself
        # falls back to 0, so that the return value is always an Integer.
        def size
          (metadata && metadata['size']) || 0
        end

        def exists?
          !metadata.nil?
        end

        def current_path
          # Return the path from @public_id if set (for retrieve scenarios),
          # otherwise fall back to reading from model
          return @public_id.to_s if @public_id.present?

          @current_path = model.send :read_attribute, serialization_column
        end
        alias path current_path

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
        def store(new_file)
          if new_file.is_a?(self.class)
            # new_file.copy_to(path)
            raise NotImplementedError, 'new file is required duplicating'
          end

          @content_type ||= if new_file.respond_to? :content_type
                              new_file.content_type
                            else
                              # Guess content-type from extension. MIME::Types returns an empty
                              # list for extensions it does not know (e.g. `.url`), so fall back
                              # to the generic binary type instead of raising NoMethodError.
                              guess_content_type(new_file.path)
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

          # NOTE: 理想的にはStorage::File内でモデルのカラムをいじらず、CarrierWaveに任せるべきだが、
          # 現在の実装では以下の理由で必要:
          # - CarrierWaveは write_uploader(column, mounter.identifiers.first) でカラムを更新
          # - mounter.identifiers -> uploaders.map(&:identifier) -> storage.identifier -> uploader.filename
          # - resizing-gemの filenameメソッドは read_column を返す（既存のカラム値）
          # - そのため、CarrierWaveに任せると旧い値が書き戻されてしまう
          # TODO: これを修正するには、Remote#identifierをオーバーライドして@public_id.to_sを返すか、
          #       uploader.filenameの実装を変更する必要がある
          # save new value to model class
          model.send :write_attribute, serialization_column, @public_id.to_s

          true
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

        def name(_options = {})
          @public_id = PublicId.new(model.send(:read_attribute, serialization_column))
          CGI.unescape(@public_id.filename)
        end

        # def copy_to(new_path)
        #   CarrierWave::Storage::Fog::File.new(@uploader, @base, new_path)
        # end

        # NOTE: Resizing::CarrierWave#file calls this on every access, so the cached metadata
        # is only dropped when the identifier actually changes.
        def retrieve(identifier)
          new_public_id = Resizing::PublicId.new(identifier)
          reset_metadata unless new_public_id.to_s == @public_id.to_s
          @public_id = new_public_id
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

        # Only clear the column if the deleted image is the current one
        # (not when deleting an old image during update)
        def clear_column_if_current_image
          return if model.destroyed?

          current_value = model.send(:read_attribute, serialization_column)
          current_public_id = Resizing::PublicId.new(current_value)

          # Only clear if the deleted image is the same as the current one
          return unless current_public_id.image_id == @public_id.image_id

          model.send :write_attribute, serialization_column, nil
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
        # Metadata of the stored image, fetched lazily from the Resizing metadata API
        # and memoized (including a failed lookup, so it is fetched at most once).
        #
        # This replaces the Fog-derived `file` method (`directory.files.head(path)`) that this
        # class used to rely on: Resizing has no equivalent of a remote file handle, and the
        # metadata endpoint is the only source of size / content_type / filename.
        #
        # === Returns
        #
        # [Hash, nil] metadata hash, or nil when there is no image or it cannot be fetched
        def metadata
          return @metadata if @metadata_fetched

          @metadata_fetched = true
          @metadata = fetch_metadata
        end

        def reset_metadata
          @metadata = nil
          @metadata_fetched = false
        end

        # NOTE: Never raises. These values are read on ordinary code paths (CarrierWave's
        # Uploader::Proxy delegates size / content_type to this object), so a transient API
        # failure must not break the caller; the absence of metadata is reported as nil.
        def fetch_metadata
          image_id = metadata_image_id
          return nil if image_id.nil? || image_id.empty?

          result = Resizing.metadata(image_id, {})
          return nil if !result.is_a?(Hash) || result['error']

          result
        rescue StandardError
          nil
        end

        # The image to look up: the identifier this instance was built with/retrieved,
        # falling back to the value currently stored in the model column.
        def metadata_image_id
          return @public_id.image_id if @public_id.present?

          Resizing::PublicId.new(model.send(:read_attribute, serialization_column)).image_id
        rescue StandardError
          nil
        end

        # Guess the content type from a file name/path.
        # Returns DEFAULT_CONTENT_TYPE when the extension is unknown to MIME::Types,
        # which is the same convention CarrierWave/Rack use for unidentifiable files.
        def guess_content_type(path)
          return DEFAULT_CONTENT_TYPE if path.nil?

          MIME::Types.type_for(path.to_s).first&.content_type || DEFAULT_CONTENT_TYPE
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
      # rubocop:enable Metrics/ClassLength
    end
  end
end
