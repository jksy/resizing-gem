# frozen_string_literal: true

module Resizing
  class MockClient
    def post(file_or_binary, options = {})
      r = load_yaml('test/vcr/client/post.yml')
      JSON.parse(r['string'])
    end

    def put(name, file_or_binary, options)
      r = load_yaml('test/vcr/client/put.yml')
      result = JSON.parse(r['string'])
      # replace name and public_id by name argument
      result['id'] = name
      result['public_id'].gsub!(/AWEaewfAreaweFAFASfwe/, name)
      result
    end

    def delete(name)
      r = load_yaml('test/vcr/client/delete.yml')
      result = JSON.parse(r['string'])
      # replace name and public_id by name argument
      result['id'] = name
      result['public_id'].gsub!(/28c49144-c00d-4cb5-8619-98ce95977b9c/, name)
      result
    end

    private

    def load_yaml filename
      path = "#{library_root}/#{filename}"
      YAML.load_file(path)['http_interactions'].first['response']['body']
    end

    def library_root
      File.join(File.dirname(__FILE__), '..', '..')
    end
  end
end
