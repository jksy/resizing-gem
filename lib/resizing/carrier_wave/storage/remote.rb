# frozen_string_literal: true

module Resizing
  module CarrierWave
    module Storage
      # ref.
      # https://github.com/carrierwaveuploader/carrierwave/blob/master/lib/carrierwave/storage/abstract.rb
      class Remote < ::CarrierWave::Storage::Abstract
        # A file cached by #cache! has already been uploaded as a temporary image, so
        # storing it only confirms it instead of uploading it again.
        def store!(file)
          if file.is_a?(Resizing::CarrierWave::Storage::File)
            file.confirm
            return file
          end

          f = Resizing::CarrierWave::Storage::File.new(uploader)
          f.store(file)
          f
        end

        # NOTE: CarrierWave 2.2.x never reaches here (Uploader::Remove#remove! calls
        # @file.delete directly), but newer versions may remove through the storage.
        # File#delete takes no argument and resolves the image to delete by itself, so
        # reuse the given file when it is already ours instead of building a new one.
        def remove!(file = nil)
          f = file.is_a?(Resizing::CarrierWave::Storage::File) ? file : Resizing::CarrierWave::Storage::File.new(uploader)
          f.delete
          f
        end

        def retrieve!(identifier)
          return nil if identifier.blank?

          f = Resizing::CarrierWave::Storage::File.new(uploader, identifier)
          f.retrieve(identifier)
          f
        end

        # Uploads the file as a temporary image. It is confirmed by #store! when the
        # model is saved; otherwise Resizing deletes it at its expires_at, so a file
        # assigned to a model that is never saved (e.g. on a validation error) does not
        # leave an orphan image behind.
        def cache!(new_file)
          f = Resizing::CarrierWave::Storage::File.new(uploader)
          f.store(new_file, temporary: true, expires_in: uploader.cache_expires_in)
          f
        end

        # The cache name of a Resizing uploader is the public id of the temporary image
        # (see Resizing::CarrierWave#cache_name).
        def retrieve_from_cache!(identifier)
          return nil if identifier.blank?

          Resizing::CarrierWave::Storage::File.new(uploader, identifier)
        end

        def delete_dir!(path)
          # do nothing, because there's no such things as 'empty directory'
        end

        # Resizing deletes the expired temporary images by itself.
        def clean_cache!(seconds)
          # do nothing
        end
      end
    end
  end
end
