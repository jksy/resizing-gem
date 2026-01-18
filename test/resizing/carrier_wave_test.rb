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
  end
end
