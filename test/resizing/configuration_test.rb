# frozen_string_literal: true

require 'test_helper'

module Resizing
  class ConfigurationTest < Minitest::Test
    ACTIVE_SUPPORT_OBJECT_EXTENSIONS = %i[present? blank? try].freeze

    def setup
      @template = {
        image_host: 'http://192.168.56.101:5000',
        video_host: 'http://192.168.56.101:5000',
        project_id: '098a2a0d-c387-4135-a071-1254d6d7e70a',
        secret_token: '4g1cshg2lq8j93ufhvqrpjswxmtjz12yhfvq6w79jpwi7cr7nnknoqgwzkwerbs6',
        open_timeout: 10,
        response_timeout: 20
      }.freeze
    end

    def teardown
      # NOP
    end

    def test_that_it_has_default_image_host
      template = @template.dup
      template.delete(:image_host)
      config = Resizing::Configuration.new template
      assert_equal(config.image_host, Resizing::Configuration::DEFAULT_IMAGE_HOST)
    end

    def test_that_it_has_default_video_host
      template = @template.dup
      template.delete(:video_host)
      config = Resizing::Configuration.new template
      assert_equal(config.video_host, Resizing::Configuration::DEFAULT_VIDEO_HOST)
    end

    def test_that_it_need_raise_exception_if_host_presented
      template = @template.dup
      template[:host] = 'need raise execption if host is presented'
      assert_raises ConfigurationError do
        _config = Resizing::Configuration.new template
      end
    end

    def test_that_it_does_not_raise_exception_if_host_is_nil
      template = @template.dup
      template[:host] = nil
      config = Resizing::Configuration.new template
      assert_equal(config.image_host, template[:image_host])
    end

    def test_that_it_does_not_raise_exception_if_host_is_empty_string
      ['', '   '].each do |host|
        template = @template.dup
        template[:host] = host
        config = Resizing::Configuration.new template
        assert_equal(config.image_host, template[:image_host])
      end
    end

    # Rails 外(ActiveSupport 未ロード)から利用されるため、
    # Configuration は present? / blank? などの ActiveSupport 拡張に依存してはいけない。
    # see: https://github.com/jksy/resizing-gem/issues/87
    def test_that_it_does_not_depend_on_active_support_object_extensions
      without_active_support_object_extensions do
        template = @template.dup
        config = Resizing::Configuration.new template
        assert_equal(config.image_host, template[:image_host])

        template_with_host = @template.dup
        template_with_host[:host] = 'https://www.resizing.net'
        assert_raises ConfigurationError do
          Resizing::Configuration.new template_with_host
        end
      end
    end

    def test_that_it_has_same_image_host_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.image_host, template[:image_host])
    end

    def test_that_it_has_same_video_host_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.video_host, template[:video_host])
    end

    def test_that_it_has_no_project_id
      template = @template.dup
      template.delete(:project_id)
      assert_raises ConfigurationError do
        Resizing::Configuration.new template
      end
    end

    def test_that_it_has_same_project_id_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.project_id, template[:project_id])
    end

    def test_that_it_has_no_secret_token
      template = @template.dup
      template.delete(:secret_token)
      assert_raises ConfigurationError do
        Resizing::Configuration.new template
      end
    end

    def test_that_it_has_same_secret_token_value
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.secret_token, template[:secret_token])
    end

    def test_that_it_has_default_open_timeout
      template = @template.dup
      template.delete(:open_timeout)
      config = Resizing::Configuration.new template
      assert_equal(config.open_timeout, Resizing::Configuration::DEFAULT_OPEN_TIMEOUT)
    end

    def test_that_it_has_same_open_timeout
      template = @template.dup
      config = Resizing::Configuration.new template
      assert_equal(config.open_timeout, template[:open_timeout])
    end

    def test_that_it_return_auth_header_token
      Timecop.freeze(Time.parse('2020-05-29 05:40:00 +0900')) do
        template = @template.dup
        config = Resizing::Configuration.new template
        assert_equal(
          'v1,1590698400,2b35ee78cd6ce32edb9b4d97b69306c678ce8dea871638ff6144b7be0d26173c',
          config.generate_auth_header
        )
      end
    end

    def test_that_it_return_image_url
      template = @template.dup
      image_id = 'some-image-id'
      config = Resizing::Configuration.new template
      assert_equal(
        'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id',
        config.generate_image_url(image_id)
      )
    end

    def test_that_it_return_image_url_with_version_id
      template = @template.dup
      image_id = 'some-image-id'
      version_id = 'version-id'
      config = Resizing::Configuration.new template
      assert_equal(
        'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id/vversion-id',
        config.generate_image_url(image_id, version_id)
      )
    end

    def test_that_it_return_transformation_path
      data = [
        { args: { w: 100 }, path: 'w_100' },
        { args: { h: 100 }, path: 'h_100' },
        { args: { f: 'webp' }, path: 'f_webp' },
        { args: { c: 'fill' }, path: 'c_fill' }
      ]
      config = Resizing::Configuration.new @template
      data.each do |v|
        assert_equal(
          v[:path],
          config.transformation_path(v[:args])
        )
      end
    end

    def test_that_it_generated_identifier_path
      config = Resizing::Configuration.new @template
      assert_match %r{/projects/#{config.project_id}/upload/images/[\da-z-]}, config.generate_identifier
    end

    def test_generate_image_id_returns_uuid
      config = Resizing::Configuration.new @template
      image_id = config.generate_image_id

      assert_instance_of String, image_id
      # UUID format: 8-4-4-4-12
      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, image_id)
    end

    def test_generate_image_id_returns_different_uuids
      config = Resizing::Configuration.new @template
      id1 = config.generate_image_id
      id2 = config.generate_image_id

      refute_equal id1, id2
    end

    def test_equality_returns_true_for_same_configurations
      config1 = Resizing::Configuration.new @template
      config2 = Resizing::Configuration.new @template

      assert_equal config1, config2
    end

    def test_equality_returns_false_for_different_image_host
      config1 = Resizing::Configuration.new @template
      template2 = @template.dup
      template2[:image_host] = 'http://different.host'
      config2 = Resizing::Configuration.new template2

      refute_equal config1, config2
    end

    def test_equality_returns_false_for_different_project_id
      config1 = Resizing::Configuration.new @template
      template2 = @template.dup
      template2[:project_id] = 'different-project-id'
      config2 = Resizing::Configuration.new template2

      refute_equal config1, config2
    end

    def test_equality_returns_false_for_different_class
      config = Resizing::Configuration.new @template

      refute_equal config, 'not a configuration'
      refute_equal config, @template
    end

    def test_transformation_path_with_multiple_transforms
      config = Resizing::Configuration.new @template
      transforms = [
        { w: 100, h: 200 },
        { f: 'webp', q: 80 }
      ]

      path = config.transformation_path(transforms)

      assert_equal 'w_100,h_200/f_webp,q_80', path
    end

    def test_transformation_path_with_single_hash
      config = Resizing::Configuration.new @template
      transform = { w: 300, h: 300, c: 'fill' }

      path = config.transformation_path(transform)

      assert_equal 'w_300,h_300,c_fill', path
    end

    def test_transformation_path_ignores_unknown_options
      config = Resizing::Configuration.new @template
      transform = { w: 100, unknown_option: 'ignored', h: 200 }

      path = config.transformation_path(transform)

      assert_equal 'w_100,h_200', path
      refute_includes path, 'unknown_option'
    end

    def test_transformation_path_with_empty_array
      config = Resizing::Configuration.new @template
      path = config.transformation_path([])

      assert_equal '', path
    end

    def test_generate_identifier_includes_project_id
      config = Resizing::Configuration.new @template
      identifier = config.generate_identifier

      assert_includes identifier, config.project_id
    end

    def test_generate_identifier_has_correct_format
      config = Resizing::Configuration.new @template
      identifier = config.generate_identifier

      assert_match %r{\A/projects/[\da-z-]+/upload/images/[\da-z-]+\z}, identifier
    end

    def test_enable_mock_defaults_to_false
      template = @template.dup
      template.delete(:enable_mock)
      config = Resizing::Configuration.new template

      assert_equal false, config.enable_mock
    end

    def test_enable_mock_can_be_set_to_true
      template = @template.dup
      template[:enable_mock] = true
      config = Resizing::Configuration.new template

      assert_equal true, config.enable_mock
    end

    def test_that_it_has_default_response_timeout
      template = @template.dup
      template.delete(:response_timeout)
      config = Resizing::Configuration.new template
      assert_equal(Resizing::Configuration::DEFAULT_RESPONSE_TIMEOUT, config.response_timeout)
    end

    def test_that_it_has_same_response_timeout
      config = Resizing::Configuration.new @template
      assert_equal(@template[:response_timeout], config.response_timeout)
    end

    def test_that_it_raises_when_initialized_without_hash
      assert_raises(ConfigurationError) { Resizing::Configuration.new }
      assert_raises(ConfigurationError) { Resizing::Configuration.new(nil) }
      assert_raises(ConfigurationError) { Resizing::Configuration.new('not a hash') }
    end

    def test_that_it_can_be_initialized_with_only_required_keys
      config = Resizing::Configuration.new(project_id: 'project', secret_token: 'token')

      assert_equal 'project', config.project_id
      assert_equal 'token', config.secret_token
      assert_equal Resizing::Configuration::DEFAULT_IMAGE_HOST, config.image_host
      assert_equal Resizing::Configuration::DEFAULT_VIDEO_HOST, config.video_host
      assert_equal Resizing::Configuration::DEFAULT_OPEN_TIMEOUT, config.open_timeout
      assert_equal Resizing::Configuration::DEFAULT_RESPONSE_TIMEOUT, config.response_timeout
      assert_equal false, config.enable_mock
    end

    def test_that_string_attributes_are_frozen_copies_of_input
      template = @template.dup
      template[:image_host] = +'http://mutable.host'
      template[:project_id] = +'mutable-project'
      template[:secret_token] = +'mutable-token'
      config = Resizing::Configuration.new template

      assert config.image_host.frozen?
      assert config.project_id.frozen?
      assert config.secret_token.frozen?

      # 入力の Hash の文字列を後から変更しても設定値には影響しない
      template[:image_host] << '/changed'
      template[:project_id] << '-changed'
      template[:secret_token] << '-changed'
      assert_equal 'http://mutable.host', config.image_host
      assert_equal 'mutable-project', config.project_id
      assert_equal 'mutable-token', config.secret_token
    end

    def test_that_auth_header_is_version_timestamp_and_sha256_of_timestamp_and_secret_token
      # サーバー側 (ResizingTokenAuthenticator) は "v1,<unix time>,<sha256>" 形式を期待している
      now = Time.parse('2024-01-02 03:04:05 UTC')
      Timecop.freeze(now) do
        config = Resizing::Configuration.new @template
        header = config.generate_auth_header

        assert_match(/\Av\d,\d+,[0-9a-f]{64}\z/, header)

        version, timestamp, token = header.split(',')
        assert_equal 'v1', version
        assert_equal now.to_i.to_s, timestamp
        assert_equal Digest::SHA2.hexdigest("#{now.to_i}|#{@template[:secret_token]}"), token
      end
    end

    def test_that_auth_header_changes_with_time
      config = Resizing::Configuration.new @template
      first = Timecop.freeze(Time.parse('2024-01-01 00:00:00 UTC')) { config.generate_auth_header }
      second = Timecop.freeze(Time.parse('2024-01-01 00:00:01 UTC')) { config.generate_auth_header }

      refute_equal first, second
    end

    def test_that_it_return_image_url_with_transformations
      config = Resizing::Configuration.new @template
      assert_equal(
        'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id/w_100,h_200',
        config.generate_image_url('some-image-id', nil, [{ w: 100, h: 200 }])
      )
    end

    def test_that_it_return_image_url_with_version_id_and_transformations
      config = Resizing::Configuration.new @template
      assert_equal(
        'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id/vversion-id/w_40,h_40,c_fill/f_webp',
        config.generate_image_url('some-image-id', 'version-id', [{ c: 'fill', w: 40, h: 40 }, { f: 'webp' }])
      )
    end

    def test_that_it_return_image_url_accepts_single_hash_transformation
      config = Resizing::Configuration.new @template
      assert_equal(
        'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id/w_100',
        config.generate_image_url('some-image-id', nil, { w: 100 })
      )
    end

    def test_that_it_return_image_url_without_trailing_slash_for_empty_transformation
      config = Resizing::Configuration.new @template
      expected = 'http://192.168.56.101:5000/projects/098a2a0d-c387-4135-a071-1254d6d7e70a/upload/images/some-image-id'

      assert_equal expected, config.generate_image_url('some-image-id', nil, [])
      assert_equal expected, config.generate_image_url('some-image-id', nil, [{}])
      assert_equal expected, config.generate_image_url('some-image-id', nil, { unknown: 1 })
    end

    def test_transformation_path_normalizes_key_order_to_transform_options_order
      # Hash#slice は引数の順で返すため、入力順に関係なく TRANSFORM_OPTIONS の順 (w, h, f, c, q) になる
      config = Resizing::Configuration.new @template

      assert_equal 'w_100,h_200', config.transformation_path(h: 200, w: 100)
      assert_equal 'w_100,h_200', config.transformation_path(w: 100, h: 200)
      assert_equal 'w_40,h_40,f_webp,c_fill,q_80', config.transformation_path(q: 80, c: 'fill', f: 'webp', h: 40, w: 40)
    end

    def test_transformation_path_with_quality
      config = Resizing::Configuration.new @template

      assert_equal 'q_80', config.transformation_path(q: 80)
      assert_equal 'w_100,q_auto', config.transformation_path(w: 100, q: 'auto')
    end

    def test_equality_returns_false_when_any_compared_attribute_differs
      base = Resizing::Configuration.new @template
      {
        video_host: 'http://different.host',
        secret_token: 'different-token',
        open_timeout: 99,
        response_timeout: 99
      }.each do |key, value|
        other = Resizing::Configuration.new @template.merge(key => value)
        refute_equal base, other, "#{key} should be compared by =="
      end
    end

    private

    def without_active_support_object_extensions
      removed = each_active_support_extension.map do |klass, method_name|
        klass.send(:alias_method, backup_name(method_name), method_name)
        klass.send(:undef_method, method_name)
        [klass, method_name]
      end

      yield
    ensure
      removed&.each do |klass, method_name|
        klass.send(:alias_method, method_name, backup_name(method_name))
        klass.send(:remove_method, backup_name(method_name))
      end
    end

    def each_active_support_extension
      [NilClass, String].product(ACTIVE_SUPPORT_OBJECT_EXTENSIONS).select do |klass, method_name|
        klass.method_defined?(method_name)
      end
    end

    def backup_name(method_name)
      :"__resizing_test_original_#{method_name}"
    end
  end
end
