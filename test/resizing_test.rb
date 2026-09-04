# frozen_string_literal: true

require 'test_helper'

class ResizingTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Resizing::VERSION
  end

  def test_version_follows_semantic_versioning
    assert_match(/\A\d+\.\d+\.\d+(\.pre)?\z/, ::Resizing::VERSION)
  end

  def test_version_is_frozen_string
    assert ::Resizing::VERSION.frozen?
  end
end
