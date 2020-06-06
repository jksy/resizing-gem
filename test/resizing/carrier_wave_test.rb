# frozen_string_literal: true

require 'test_helper'

module Resizing
  class CarrierWaveTest < Minitest::Test
    def setup
      TestModel.delete_all

      @configuration_template = {
        host: 'http://192.168.56.101:5000',
        project_id: '098a2a0d-c387-4135-a071-1254d6d7e70a',
        secret_token: '4g1cshg2lq8j93ufhvqrpjswxmtjz12yhfvq6w79jpwi7cr7nnknoqgwzkwerbs6',
        open_timeout: 10,
        response_timeout: 20
      }
      Resizing.configure = @configuration_template
    end

    def teardown; end

    def test_xxxx
      model = prepare_model

      VCR.use_cassette 'carrier_wave_test/remove_resizing_picture' do
        SecureRandom.stub :uuid, '28c49144-c00d-4cb5-8619-98ce95977b9c' do
          model.remove_resizing_picture!

          assert_equal(model.resizing_picture_url, nil)
        end
      end
    end

    def test_picture_url_return_correct_value_and_when_model_reloaded
      model = prepare_model
      model.save!
      assert_equal(expect_url, model.resizing_picture_url)

      model.reload
      assert_equal(expect_url, model.resizing_picture_url)
    end

    def expect_url
      'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/'+
        'upload/images/28c49144-c00d-4cb5-8619-98ce95977b9c/v1Id850__tqNsnoGWWUibtIBZ5NgjV45M/c_limit,w_1000'
    end

    def prepare_model
      VCR.use_cassette 'carrier_wave_test/save' do
        SecureRandom.stub :uuid, '28c49144-c00d-4cb5-8619-98ce95977b9c' do
          model = TestModel.new
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
  end
end
