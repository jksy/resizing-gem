# frozen_string_literal: true

require 'test_helper'

module Resizing
  # Resizing::CarrierWave の一時画像を使ったキャッシュの扱いをテストする
  #
  # - 代入 (cache!) では一時画像としてアップロードし、確定はしない
  # - 保存 (コミット後の store!) で一時画像を確定する
  # - フォームの再表示で送り返された `<column>_cache` から一時画像を復元する
  class CarrierWaveTemporaryImageTest < Minitest::Test
    include VCRRequestAssertions
    include ResizingTestConfiguration

    IMAGE_ID = '14ea7aac-a194-4330-931f-6b562aec413d'
    OTHER_PROJECT_IDENTIFIER = '/projects/00000000-0000-0000-0000-000000000000/upload/images/' \
                               "#{IMAGE_ID}/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e".freeze

    def setup
      TestModel.delete_all
      configure_resizing
    end

    def teardown; end

    # ============================================================
    # 代入時のアップロード
    # ============================================================

    def test_assignment_uploads_image_as_temporary
      model = TestModel.new

      posted = capture_post_options do
        assert_vcr_requests_made('carrier_wave_test/save') { attach_sample_image(model) }
      end

      assert_equal 1, posted.size
      assert_equal true, posted.first[:temporary]
      assert_nil posted.first[:expires_in]
    end

    def test_assignment_sends_cache_expires_in_of_uploader
      model = TestModelWithCacheExpiresIn.new

      posted = capture_post_options do
        assert_vcr_requests_made('carrier_wave_test/save') { attach_sample_image(model) }
      end

      assert_equal true, posted.first[:temporary]
      assert_equal 3600, posted.first[:expires_in]
    end

    def test_assignment_does_not_confirm_image
      model = TestModel.new

      assert_vcr_no_requests 'carrier_wave_test/confirm' do
        assert_vcr_requests_made('carrier_wave_test/save') { attach_sample_image(model) }
      end

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    # ============================================================
    # 保存時の確定
    # ============================================================

    def test_save_confirms_temporary_image
      model = prepare_model

      assert_vcr_requests_made 'carrier_wave_test/confirm' do
        model.save!
      end

      assert_equal expect_identifier, TestModel.find(model.id).read_attribute(:resizing_picture)
      assert_nil model.resizing_picture_cache
    end

    def test_rolled_back_save_leaves_no_image
      model = prepare_model

      if carrierwave3?
        # CarrierWave 3.x は保存中 (after_save) に確定し、ロールバックされると追加した画像を削除する
        VCR.use_cassette('carrier_wave_test/confirm', record: :none) do
          assert_vcr_requests_made('carrier_wave_test/remove_resizing_picture') { save_and_roll_back(model) }
        end
      else
        # CarrierWave 2.x はコミット後に確定するので、ロールバックされると確定しない (一時画像は期限で削除される)
        assert_vcr_no_requests('carrier_wave_test/confirm') { save_and_roll_back(model) }
      end
    end

    def save_and_roll_back(model)
      ActiveRecord::Base.transaction do
        model.save!
        raise ActiveRecord::Rollback
      end
    end

    def test_saving_again_does_not_confirm_stored_image_again
      model = prepare_model
      VCR.use_cassette('carrier_wave_test/confirm', record: :none) { model.save! }

      assert_vcr_no_requests 'carrier_wave_test/confirm' do
        model.save!
        TestModel.find(model.id).save!
      end
    end

    def test_confirm_failure_is_raised_on_save
      # 期限切れなどで確定できなかった場合は、画像のないレコードを黙って残さずに例外にする
      model = prepare_model
      error = Resizing::APIError.new('expired')

      Resizing::Client.stub(:new, failing_confirm_client(error)) do
        raised = assert_raises(Resizing::APIError) { model.save! }
        assert_same error, raised
      end
    end

    def test_store_with_new_file_uploads_temporary_image_and_confirms_it
      uploader = TestModel.new.resizing_picture

      posted = capture_post_options do
        assert_vcr_requests_made 'carrier_wave_test/confirm' do
          assert_vcr_requests_made('carrier_wave_test/save') { uploader.store!(sample_uploaded_file) }
        end
      end

      assert_equal true, posted.first[:temporary]
      assert_equal expect_identifier, uploader.identifier
      refute uploader.cached?
    end

    # ============================================================
    # <column>_cache による一時画像の復元
    # ============================================================

    def test_cache_returns_public_id_of_temporary_image
      model = prepare_model

      assert_equal expect_identifier, model.resizing_picture_cache
    end

    def test_cache_is_nil_for_model_loaded_from_db
      model = TestModel.new
      model.send(:write_attribute, :resizing_picture, expect_identifier)
      model.save!

      assert_nil TestModel.find(model.id).resizing_picture_cache
    end

    def test_cache_name_restores_temporary_image
      model = TestModel.new

      assert_vcr_requests_made 'carrier_wave_test/retrieve_from_cache' do
        model.resizing_picture_cache = expect_identifier
      end

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
      assert_equal "#{expect_url}/", model.resizing_picture_url
      assert_equal expect_identifier, model.resizing_picture_cache

      # 復元した一時画像は保存時に確定する
      assert_vcr_requests_made 'carrier_wave_test/confirm' do
        model.save!
      end
      assert_equal expect_identifier, TestModel.find(model.id).read_attribute(:resizing_picture)
    end

    def test_cache_name_replaces_image_of_persisted_model
      model = TestModel.new
      model.send(:write_attribute, :resizing_picture, '/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/old/v1')
      model.save!
      model = TestModel.find(model.id)

      VCR.use_cassette('carrier_wave_test/retrieve_from_cache', record: :none) do
        model.resizing_picture_cache = expect_identifier
      end

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_assigning_public_id_of_temporary_image_restores_it
      # 文字列の代入も CarrierWave は cache name として扱う
      model = TestModel.new

      assert_vcr_requests_made 'carrier_wave_test/retrieve_from_cache' do
        model.resizing_picture = expect_identifier
      end

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_cache_name_uses_public_id_returned_by_resizing
      # 送られてきた version ではなく、Resizing が返した public_id を書き込む
      model = TestModel.new
      tampered = expect_identifier.sub(/v[^v]+\z/, 'vtampered')

      VCR.use_cassette('carrier_wave_test/retrieve_from_cache', record: :none) do
        model.resizing_picture_cache = tampered
      end

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    def test_cache_name_of_confirmed_image_is_ignored
      # 確定済みの画像は他のレコードの画像かもしれないので、cache name では付け替えない
      assert_cache_name_ignored(metadata: { 'public_id' => expect_identifier, 'temporary' => false })
    end

    def test_cache_name_of_expired_or_deleted_image_is_ignored
      # 期限切れの一時画像には削除前でも 404 が返る
      assert_cache_name_ignored(
        metadata: { 'error' => 'ActiveRecord::RecordNotFound', 'message' => "#{IMAGE_ID} expired" }
      )
    end

    def test_cache_name_of_other_project_is_ignored_without_request
      assert_cache_name_ignored(cache_name: OTHER_PROJECT_IDENTIFIER)
    end

    def test_malformed_cache_name_is_ignored_without_request
      assert_cache_name_ignored(cache_name: 'not-a-public-id')
    end

    def test_retrieve_from_cache_raises_invalid_parameter_for_invalid_cache_name
      uploader = TestModel.new.resizing_picture

      assert_raises(::CarrierWave::InvalidParameter) { uploader.retrieve_from_cache!('not-a-public-id') }
      assert_raises(::CarrierWave::InvalidParameter) { uploader.retrieve_from_cache!('') }
    end

    def test_blank_cache_name_keeps_assigned_image
      model = prepare_model

      model.resizing_picture_cache = ''

      assert_equal expect_identifier, model.read_attribute(:resizing_picture)
    end

    private

    def prepare_model
      model = TestModel.new
      VCR.use_cassette('carrier_wave_test/save', record: :none) { attach_sample_image(model) }
      model
    end

    # ブロック内で Resizing.post に渡されたオプションを記録する (リクエストはそのまま発行する)
    def capture_post_options(&block)
      posted = []
      original = Resizing.method(:post)
      spy = lambda do |file, options|
        posted << options
        original.call(file, options)
      end
      Resizing.stub(:post, spy, &block)
      posted
    end

    def failing_confirm_client(error)
      client = Object.new
      client.define_singleton_method(:confirm) { |_image_id| raise error }
      client
    end

    # cache name を受け付けず、モデルに画像が付かないこと
    # metadata を渡した場合はその応答を返し、渡さない場合はリクエストしないことを確認する
    def assert_cache_name_ignored(cache_name: expect_identifier, metadata: nil)
      model = TestModel.new
      looked_up = []
      responder = lambda do |image_id, _options|
        flunk "metadata must not be requested for #{cache_name}" if metadata.nil?

        looked_up << image_id
        metadata
      end

      Resizing.stub(:metadata, responder) do
        model.resizing_picture_cache = cache_name
      end

      assert_equal(metadata.nil? ? [] : [IMAGE_ID], looked_up)
      assert_nil model.read_attribute(:resizing_picture)
      assert model.resizing_picture.blank?
      assert_nil model.resizing_picture_cache
    end
  end
end
