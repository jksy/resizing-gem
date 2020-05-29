module Resizing
  module CarrierWave
    module Storage
      class RemoteTest < Minitest::Test
        def setup
          # NOP
        end

        def teardown
          # NOP
        end

        def test_afadf
          File.new(uploader, path)
        end
      end
    end
  end
end
