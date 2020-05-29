module Resizing
  module CarrierWave
    module Storage
      class FileTest < Minitest::Test
        def setup
          # NOP
        end

        def teardown
          # NOP
        end

        def test_afadf
          f = Resizing::CarrierWave::Storage::File.new(
            uploader,
            uploader.cache_path
          )
          File.new(uploader, path)
        end

        def uploader
        end
      end
    end
  end
end
