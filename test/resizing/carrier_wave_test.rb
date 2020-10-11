# frozen_string_literal: true

require 'test_helper'

module Resizing
  class CarrierWaveTest < Minitest::Test
    def setup
      TestModel.delete_all
      TestJPGModel.delete_all

      @configuration_template = {
        host: 'http://192.168.56.101:5000',
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

      VCR.use_cassette 'carrier_wave_test/remove_resizing_picture' do
        SecureRandom.stub :uuid, '28c49144-c00d-4cb5-8619-98ce95977b9c' do
          model.remove_resizing_picture!

          assert_nil model.resizing_picture_url
        end
      end
    end

    def test_do_not_raise_if_empty_column_is_removed
      model = prepare_model TestModel

      VCR.use_cassette 'carrier_wave_test/remove_resizing_picture' do
        SecureRandom.stub :uuid, '28c49144-c00d-4cb5-8619-98ce95977b9c' do
          model.resizing_picture.remove!
        end
      end
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
      model = prepare_model_with_tempfile TestModel
      model.save!
      # assert_equal('http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/28c49144-c00d-4cb5-8619-98ce95977b9c/v1Id850__tqNsnoGWWUibtIBZ5NgjV45M/', model.resizing_picture_url)
    end

    def expect_url
      'http://192.168.56.101:5000/projects/e06e710d-f026-4dcf-b2c0-eab0de8bb83f/'+
        'upload/images/14ea7aac-a194-4330-931f-6b562aec413d/v_8c5lEhDB5RT3PZp1Fn5PYGm9YVx_x0e'
    end

    def prepare_model model
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        SecureRandom.stub :uuid, '28c49144-c00d-4cb5-8619-98ce95977b9c' do
          model = model.new
          file = File.open('test/data/images/sample1.jpg', 'r')
          uploaded_file = ActionDispatch::Http::UploadedFile.new(
            filename: File.basename(file.path),
            type: 'image/jpeg',
            tempfile: file
          )

          model.resizing_picture = uploaded_file
          return model
        end
      end
    end

    def prepare_model_with_tempfile model
      VCR.use_cassette 'carrier_wave_test/save', record: :once do
        SecureRandom.stub :uuid, '28c49144-c00d-4cb5-8619-98ce95977b9c' do
          model = model.new
          file = File.open('test/data/images/sample1.jpg', 'r')
          model.resizing_picture = file
          return model
        end
      end
    end
  end
end
