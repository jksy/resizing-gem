# frozen_string_literal: true

require 'test_helper'

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

        def test_store
          # f = Resizing::CarrierWave::Storage::File.new(uploader)
          # upload_file = File.new(uploader, path)
          # f.store(upload_file)
          # f.save!
        end

        def uploader
          MiniTest::Mock.expect(:cache_path)
        end
      end
    end
  end
end
