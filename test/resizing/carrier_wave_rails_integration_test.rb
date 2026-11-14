# frozen_string_literal: true

require 'test_helper'
require_relative '../rails_app/rails_app'

module Resizing
  # README の「Making uploads work across form redisplays」の例を、Rails アプリに組み込んだ形で確認する
  # (フォームの表示 → バリデーションエラーで再表示 → image_cache を送り返して保存)
  class CarrierWaveRailsIntegrationTest < ActionDispatch::IntegrationTest
    include VCRRequestAssertions
    include ResizingTestConfiguration

    def setup
      User.delete_all
      configure_resizing
    end

    def test_new_form_is_multipart_with_empty_image_cache
      get '/users/new'

      assert_response :ok
      assert_includes response.body, 'enctype="multipart/form-data"'
      assert_equal '', image_cache_in(response.body)
    end

    def test_form_shown_again_after_validation_error_keeps_temporary_image
      assert_vcr_no_requests 'carrier_wave_test/confirm' do
        assert_vcr_requests_made 'carrier_wave_test/save' do
          post '/users', params: { user: { name: '', image: sample_upload, image_cache: '' } }
        end
      end

      assert_response :unprocessable_entity
      assert_equal expect_identifier, image_cache_in(response.body)
      assert_equal 0, User.count
    end

    def test_resubmitting_image_cache_saves_and_confirms_the_image
      assert_vcr_requests_made 'carrier_wave_test/retrieve_from_cache' do
        assert_vcr_requests_made 'carrier_wave_test/confirm' do
          post '/users', params: { user: { name: 'Alice', image_cache: expect_identifier } }
        end
      end

      user = User.last
      assert_redirected_to "/users/#{user.id}"
      assert_equal expect_identifier, user.read_attribute(:image)
      assert_equal "#{expect_url}/", user.image_url
    end

    def test_image_cache_left_out_of_strong_parameters_is_dropped
      assert_vcr_no_requests 'carrier_wave_test/retrieve_from_cache' do
        post '/users_without_cache', params: { user: { name: 'Bob', image_cache: expect_identifier } }
      end

      user = User.last
      assert_redirected_to "/users/#{user.id}"
      assert_nil user.read_attribute(:image)
    end

    private

    def sample_upload
      Rack::Test::UploadedFile.new('test/data/images/sample1.jpg', 'image/jpeg')
    end

    # name 属性と value 属性の順序に依存せずに hidden field の値を取り出す
    def image_cache_in(html)
      tag = html[/<input[^>]*name="user\[image_cache\]"[^>]*>/]
      assert tag, 'image_cache hidden field should be rendered'
      tag[/value="([^"]*)"/, 1].to_s
    end
  end
end
