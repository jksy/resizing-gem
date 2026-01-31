# frozen_string_literal: true

require 'test_helper'

class ResizingTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Resizing::VERSION
  end

  def test_file_part_class_returns_valid_class
    klass = Resizing.file_part_class
    # Should return either Faraday::Multipart::FilePart (Faraday 2.x) or Faraday::UploadIO (Faraday 1.x)
    assert [Faraday::Multipart::FilePart, Faraday::UploadIO].include?(klass),
           "Expected Faraday::Multipart::FilePart or Faraday::UploadIO, got #{klass}"
  end

  def test_file_part_class_returns_faraday_multipart_file_part_when_defined
    # Faraday::Multipart::FilePart is defined when faraday-multipart gem is loaded
    if defined?(Faraday::Multipart::FilePart)
      assert_equal Faraday::Multipart::FilePart, Resizing.file_part_class
    else
      assert_equal Faraday::UploadIO, Resizing.file_part_class
    end
  end
end
