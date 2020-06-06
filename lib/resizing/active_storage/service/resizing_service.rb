module Resizing
  module ActiveStorage
    module Service
      # ref.
      # https://github.com/rails/rails/blob/master/activestorage/lib/active_storage/service/s3_service.rb
      class ResizingService < ::ActiveStorage::Service
        # def initialize(bucket:, upload: {}, public: false, **options)
        def initialize; end

        def upload(_key, _io, checksum: nil, filename: nil, content_type: nil, disposition: nil, **)
          raise NotImplementedError, 'upload is not implemented'
        end

        def download(_key)
          raise NotImplementedError, 'download is not implemented'
        end

        def download_chunk(_key, _range)
          raise NotImplementedError, 'download_chunk is not implemented'
        end

        def delete(_key)
          raise NotImplementedError, 'delete is not implemented'
        end

        def exist?(_key)
          raise NotImplementedError, 'exist? is not implemented'
        end

        def url_for_direct_upload(_key, expires_in:, content_type:, conteont_length:, checksum:)
          raise NotImplementedError, 'url_for_direct_upload is not implemented'
        end

        def headers_for_direct_upload(_key, content_type:, checksum:, filename: nil, disposition: nil, **)
          raise NotImplementedError, 'headers_for_direct_upload is not implemented'
        end

        private

        # call from ActiveStorage::Service.url
        # https://github.com/rails/rails/blob/master/activestorage/lib/active_storage/service.rb#L111
        def private_url(_key, expires_in:, filename:, content_type:, disposition:, **)
          raise NotImplementedError, 'private_url is not implemented'
        end

        def public_url(_key, filename:, content_type: nil, disposition: :attachment, **)
          raise NotImplementedError, 'public_url is not implemented'
        end
      end
    end
  end
end
