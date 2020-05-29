require "test_helper"

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
          f = Resizing::CarrierWave::Storage::File.new(uploader)
          upload_file = File.new(uploader, path)
          f.store(upload_file)
          f.save!
        end

        def uploader
          MiniTest::Mock.expect(:cache_path)
        end
      end

      class TestModel < ::ActiveRecord::Base
        establish_connection({
          adapter: 'mysql2',
          host: '127.0.0.1',
          pool: 5,
          port: 3306,
          username: 'test',
          password: 'secret',
          database: 'test',
        })
      end
    end
  end
end
