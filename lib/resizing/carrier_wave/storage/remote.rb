# frozen_string_literal: true

module Resizing
  module CarrierWave
    module Storage
      # ref.
      # https://github.com/carrierwaveuploader/carrierwave/blob/master/lib/carrierwave/storage/abstract.rb
      class Remote < ::CarrierWave::Storage::Abstract
        def store!(file)
          f = Resizing::CarrierWave::Storage::File.new(uploader)
          f.store(file)
          f
        end

        def remove!(file)
          f = Resizing::CarrierWave::Storage::File.new(uploader)
          f.delete(file)
          f
        end

        # def retrieve!(identifier)
        #   super
        # end

        def cache!(new_file)
          f = Resizing::CarrierWave::Storage::File.new(uploader)
          f.store(new_file)
          f
        end

        def retrieve_from_cache!(identifier)
          # NOP
          # Resizing::CarrierWave::Storage::File..new(uploader, uploader.cache_path(identifier))
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
    end
  end
end
