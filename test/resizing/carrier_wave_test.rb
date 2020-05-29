require "test_helper"

module Resizing
  class CarrierWaveTest < Minitest::Test
    def setup
    end

    def teardown
    end

    def test_WIP
      puts '==========================='
      model = TestModel.new
      puts model.inspect
      file = File.open('test/data/images/sample1.jpg','r')
      model.resizing_picture = file
      puts model.inspect
      model.save!
      model.resizing_picture_url
      assert_equal('', model.resizing_picture_url)
      puts model.reload.inspect
    end
  end
end
