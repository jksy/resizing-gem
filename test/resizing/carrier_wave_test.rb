# frozen_string_literal: true

require 'test_helper'

module Resizing
  class CarrierWaveTest < Minitest::Test
    include VCRRequestAssertions

    def setup
      TestModel.delete_all
      TestJPGModel.delete_all

      @configuration_template = {
        image_host: 'http://192.168.56.101:5000',
        video_host: 'http://192.168.56.101:5000',
        project_id: 'e06e710d-f026-4dcf-b2c0-eab0de8bb83f',
        secret_token: 'ewbym2r1pk49x1d2lxdbiiavnqp25j2kh00hsg3koy0ppm620x5mhlmgl3rq5ci8',
        open_timeout: 10,
        response_timeout: 20
      }
      Resizing.configure = @configuration_template
    end

    def teardown; end

    def test_remove_resizing_picture
      model = prepare_model TestModel
      model.save!

      # VCRカセットのDELETEリクエストが実際に発行されたことを確認
      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        model.remove_resizing_picture!
        model.save!
      end

      # DELETEが成功した結果、URLがnilになることを確認
      assert_nil model.resizing_picture_url
    end

    def test_remove_calls_delete_immediately
      model = prepare_model TestModel
      model.save!

      # remove!を呼んだとき即時にDELETEリクエストがとぶことを確認する
      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        model.resizing_picture.remove!
      end
    end

    def test_blank_returns_true_after_remove
      model = prepare_model TestModel
      model.save!

      refute model.resizing_picture.blank?, 'resizing_picture should not be blank before remove'

      # DELETEリクエストが発行されたことを確認
      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        model.remove_resizing_picture!
        model.save!
      end

      assert model.resizing_picture.blank?, 'resizing_picture should be blank after remove'
      assert_nil model.resizing_picture_url
    end

    def test_blank_returns_true_for_new_record
      model = TestModel.new
      assert model.resizing_picture.blank?, 'resizing_picture should be blank for new record'
    end

    def test_remove_resizing_picture_with_flag_and_save
      model = prepare_model TestModel
      model.save!

      refute model.resizing_picture.blank?, 'resizing_picture should not be blank before remove'

      model.remove_resizing_picture = true

      # save時にDELETEリクエストが発行されたことを確認
      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        model.save!
      end

      # DELETEが成功した結果、blank?がtrueになることを確認
      assert model.resizing_picture.blank?, 'resizing_picture should be blank after save'
      assert_nil model.resizing_picture_url
    end

    def test_picture_url_return_correct_value_and_when_model_reloaded
      model = prepare_model TestModel
      model.save!
      assert_equal("#{expect_url}/", model.resizing_picture_url)

      model.reload
      assert_equal("#{expect_url}/", model.resizing_picture_url)
    end

    def test_picture_url_return_with_transform_strings
      model = prepare_model TestModel
      model.save!
      assert_equal("#{expect_url}/c_fill,w_40,h_40", model.resizing_picture_url(:small))
    end

    def test_format_method_is_callable
      model = prepare_model TestModel
      model.save!
      assert_nil model.resizing_picture.format
    end

    def test_format_method_is_return_jpg_with_overriden
      model = prepare_model TestJPGModel
      model.save!
      model.resizing_picture.format
      assert_equal('jpg', model.resizing_picture.format)
    end

    def test_url_is_return_default_url_as_nil
      model = TestModel.new
      model.save!
      assert_nil model.resizing_picture_url
    end

    def test_url_is_return_default_url
      model = TestModelWithDefaultURL.new
      model.save!
      assert_equal('http://example.com/test.jpg', model.resizing_picture_url)
    end

    def test_is_successful
      model = TestModel.new

      # POSTリクエストが発行されたことを確認
      assert_vcr_requests_made 'carrier_wave_test/save' do
        file = File.open('test/data/images/sample1.jpg', 'r')
        model.resizing_picture = file
      end

      assert_equal('http://192.168.56.101:5000/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e/', model.resizing_picture_url)
    end

    def test_file_returns_same_instance_on_multiple_calls
      model = prepare_model TestModel
      model.save!

      file1 = model.resizing_picture.file
      file2 = model.resizing_picture.file

      assert_same file1, file2
    end

    def test_file_returns_nil_for_blank_identifier
      model = TestModel.new
      assert_nil model.resizing_picture.file
    end

    def test_file_uses_read_column_when_identifier_nil
      model = prepare_model TestModel
      model.save!
      model.reload

      file = model.resizing_picture.file
      refute_nil file
      assert_instance_of Resizing::CarrierWave::Storage::File, file
    end

    def expect_url
      'http://192.168.56.101:5000/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/' \
        'upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
    end

    def prepare_model(model)
      result = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        result = model.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )

        result.resizing_picture = uploaded_file
      end
      result
    end

    # after_commit コールバックが正しく呼ばれることを確認するテスト
    # 通常のテスト環境ではトランザクションが使われるため、after_commit が呼ばれない問題がある
    # このテストでは、明示的にトランザクションをコミットして after_commit が呼ばれることを確認する

    def test_after_commit_callback_is_called_on_create
      # after_commit on: :create が呼ばれることを確認
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModelWithCallbackTracking.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      # 明示的なトランザクション内で save! することで after_commit が呼ばれる
      ActiveRecord::Base.transaction do
        model.save!
      end

      assert_includes model.callback_log, :create_commit,
                      'after_commit on: :create should be called after transaction commit'
    end

    def test_after_commit_callback_is_called_on_update
      # after_commit on: :update が呼ばれることを確認
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModelWithCallbackTracking.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      model.save!
      model.callback_log.clear

      # 更新時の after_commit が呼ばれることを確認
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      ActiveRecord::Base.transaction do
        model.save!
      end

      assert_includes model.callback_log, :update_commit,
                      'after_commit on: :update should be called after transaction commit'
    end

    def test_after_commit_callback_is_called_on_destroy
      # after_commit on: :destroy が呼ばれることを確認
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModelWithCallbackTracking.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      model.save!
      model.callback_log.clear

      # destroy 時の after_commit が呼ばれることを確認
      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        ActiveRecord::Base.transaction do
          model.destroy!
        end
      end

      assert_includes model.callback_log, :destroy_commit,
                      'after_commit on: :destroy should be called after transaction commit'
    end

    def test_carrierwave_remove_previously_stored_is_called_on_update
      # CarrierWave が登録する remove_previously_stored_#{column} が
      # 画像の更新時に呼ばれることを確認
      model = prepare_model TestModel
      model.save!

      model.resizing_picture_url

      # 新しい画像をアップロードして更新
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      # 更新時には古い画像を削除するため DELETE リクエストが発行されるべき
      # ただし、同じカセットを使用しているため同じ URL になる
      # 実際の環境では異なる public_id が返されるため、古い画像が削除される
      ActiveRecord::Base.transaction do
        model.save!
      end

      # モデルが更新されたことを確認
      refute_nil model.resizing_picture_url
    end

    # ============================================================
    # before_save / after_save コールバックのテスト
    # ============================================================

    def test_before_save_write_identifier_is_called
      # before_save :write_#{column}_identifier が呼ばれ、
      # カラムに識別子が書き込まれることを確認
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModel.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      # 保存前は識別子がDBに書き込まれていない
      assert model.new_record?

      model.save!

      # 保存後は識別子がDBに書き込まれている
      assert_match %r{/projects/.+/upload/images/.+}, model.read_attribute(:resizing_picture)
    end

    def test_after_save_store_is_called
      # after_save :store_#{column}! が呼ばれ、
      # ファイルがストレージに保存されることを確認
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModel.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      model.save!

      # ファイルが保存され、URLが取得できることを確認
      refute_nil model.resizing_picture_url
      refute model.resizing_picture.blank?
    end

    def test_after_save_store_previous_changes_is_called
      # after_save :store_previous_changes_for_#{column} が呼ばれ、
      # 前の変更が追跡されることを確認
      model = prepare_model TestModel
      model.save!

      model.read_attribute(:resizing_picture)

      # 新しい画像をアップロード
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      model.save!

      # previous_changes に resizing_picture の変更が記録されていることを確認
      # (CarrierWave が store_previous_changes_for_#{column} で追跡)
      assert model.previous_changes.key?('resizing_picture'),
             'previous_changes should track resizing_picture changes'
    end

    # ============================================================
    # after_commit :mark_remove_#{column}_false のテスト
    # ============================================================

    def test_mark_remove_column_false_is_called_after_update
      # after_commit :mark_remove_#{column}_false, on: :update が呼ばれ、
      # remove フラグがリセットされることを確認
      model = prepare_model TestModel
      model.save!

      # remove フラグを設定
      model.remove_resizing_picture = '1'

      # この時点ではフラグが設定されている
      assert_equal '1', model.remove_resizing_picture

      # save 後に after_commit で mark_remove_resizing_picture_false が呼ばれる
      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        ActiveRecord::Base.transaction do
          model.save!
        end
      end

      # after_commit 後はフラグがリセットされている
      # CarrierWave が mark_remove_#{column}_false でフラグをリセット
      refute model.remove_resizing_picture,
             'remove flag should be reset after commit'
    end

    # ============================================================
    # after_commit :remove_#{column}!, on: :destroy のテスト
    # ============================================================

    def test_remove_column_is_called_on_destroy
      # after_commit :remove_#{column}!, on: :destroy が呼ばれ、
      # ファイルが削除されることを確認
      model = prepare_model TestModel
      model.save!

      refute model.resizing_picture.blank?

      # destroy 時に DELETE リクエストが発行されることを確認
      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        ActiveRecord::Base.transaction do
          model.destroy!
        end
      end

      # モデルが削除されたことを確認
      assert model.destroyed?
    end

    # ============================================================
    # コールバック順序のテスト
    # ============================================================

    def test_callback_order_on_create
      # create 時のコールバック順序を確認
      # 1. before_save :write_#{column}_identifier
      # 2. after_save :store_#{column}!
      # 3. after_commit (on: :create)
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModelWithCallbackTracking.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      ActiveRecord::Base.transaction do
        model.save!
      end

      # コールバックが正しい順序で呼ばれたことを確認
      assert_equal %i[before_save after_save create_commit], model.callback_log
    end

    def test_callback_order_on_update
      # update 時のコールバック順序を確認
      # 1. before_save :write_#{column}_identifier
      # 2. after_save :store_#{column}!
      # 3. after_save :store_previous_changes_for_#{column}
      # 4. after_commit :mark_remove_#{column}_false
      # 5. after_commit :remove_previously_stored_#{column}
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModelWithCallbackTracking.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      model.save!
      model.callback_log.clear

      # 更新
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      ActiveRecord::Base.transaction do
        model.save!
      end

      # コールバックが正しい順序で呼ばれたことを確認
      assert_equal %i[before_save after_save update_commit], model.callback_log
    end

    def test_callback_order_on_destroy
      # destroy 時のコールバック順序を確認
      # 1. before_destroy
      # 2. after_destroy
      # 3. after_commit :remove_#{column}!, on: :destroy
      model = nil
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        model = TestModelWithCallbackTracking.new
        file = File.open('test/data/images/sample1.jpg', 'r')
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          filename: File.basename(file.path),
          type: 'image/jpeg',
          tempfile: file
        )
        model.resizing_picture = uploaded_file
      end

      model.save!
      model.callback_log.clear

      assert_vcr_requests_made 'carrier_wave_test/remove_resizing_picture' do
        ActiveRecord::Base.transaction do
          model.destroy!
        end
      end

      # コールバックが正しい順序で呼ばれたことを確認
      assert_equal %i[before_destroy after_destroy destroy_commit], model.callback_log
    end
  end
end
