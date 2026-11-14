# frozen_string_literal: true

require 'securerandom'

module Resizing
  class MockClient
    # Resizing の既定の一時画像の有効期限 (秒)
    DEFAULT_TEMPORARY_EXPIRES_IN = 24 * 60 * 60

    def post(_file_or_binary, options = {})
      r = load_yaml('test/vcr/client/post.yml')
      result = JSON.parse(r['string'])
      # temporary を指定したときは一時画像として返す
      result['temporary'] = options[:temporary] ? true : false
      result['expires_at'] = (temporary_expires_at(options[:expires_in]) if options[:temporary])
      result
    end

    def confirm(name)
      r = load_yaml('test/vcr/client/metadata.yml')
      result = JSON.parse(r['string'])
      # カセット内の値に依存せず、name で id / public_id を組み立て直す
      result['id'] = name
      result['public_id'] = build_public_id(result['public_id'], image_id: name)
      result['temporary'] = false
      result['expires_at'] = nil
      result
    end

    def put(name, _file_or_binary, _options)
      r = load_yaml('test/vcr/client/put.yml')
      result = JSON.parse(r['string'])
      # カセット内の値に依存せず、name と新しい version で id / public_id を組み立て直す
      version = generate_version
      result['id'] = name
      result['version'] = version
      result['latest_version_id'] = version
      result['public_id'] = build_public_id(result['public_id'], image_id: name, version: version)
      result
    end

    def delete(name)
      r = load_yaml('test/vcr/client/delete.yml')
      result = JSON.parse(r['string'])
      # カセット内の値に依存せず、name で id / public_id を組み立て直す
      result['id'] = name
      result['public_id'] = build_public_id(result['public_id'], image_id: name)
      result
    end

    def metadata(name, _options = {})
      r = load_yaml('test/vcr/client/metadata.yml')
      result = JSON.parse(r['string'])
      # カセット内の値に依存せず、name で id / public_id を組み立て直す
      result['id'] = name
      result['public_id'] = build_public_id(result['public_id'], image_id: name)
      result
    end

    private

    # カセットの public_id を PublicId で分解し、image_id / version を差し替えて組み立て直す
    def build_public_id(public_id, image_id:, version: nil)
      parsed = Resizing::PublicId.new(public_id)
      version ||= parsed.version
      identifier = "/projects/#{parsed.project_id}/upload/images/#{image_id}"
      version.nil? ? identifier : "#{identifier}/v#{version}"
    end

    def temporary_expires_at(expires_in)
      seconds = expires_in.nil? ? DEFAULT_TEMPORARY_EXPIRES_IN : expires_in.to_i
      (Time.now + seconds).utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
    end

    def generate_version
      SecureRandom.alphanumeric(32)
    end

    def load_yaml(filename)
      path = "#{library_root}/#{filename}"
      YAML.load_file(path)['http_interactions'].first['response']['body']
    end

    def library_root
      @library_root ||= File.expand_path('../..', __dir__)
    end
  end
end
