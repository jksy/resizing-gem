# frozen_string_literal: true

require 'test_helper'

module Resizing
  module CarrierWave
    module Storage
      class RemoteTest < Minitest::Test
        def setup
          @uploader = Minitest::Mock.new
          @storage = Remote.new(@uploader)
        end

        def teardown
          # NOP
        end

        def test_storage_has_required_methods
          assert_respond_to @storage, :store!
          assert_respond_to @storage, :remove!
          assert_respond_to @storage, :cache!
          assert_respond_to @storage, :retrieve_from_cache!
          assert_respond_to @storage, :delete_dir!
          assert_respond_to @storage, :clean_cache!
        end

        def test_retrieve_from_cache_returns_nil
          result = @storage.retrieve_from_cache!('identifier')
          assert_nil result
        end

        def test_delete_dir_does_nothing
          # Should not raise any exception
          assert_nil @storage.delete_dir!('/path/to/dir')
        end

        def test_clean_cache_does_nothing
          # Should not raise any exception
          assert_nil @storage.clean_cache!(3600)
        end

        def test_storage_initialization
          assert_instance_of Remote, @storage
        end
      end
    end
  end
end
