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
      # replace name, public_id and version by name argument
      result['id'] = name
      result['public_id'].gsub!(/AWEaewfAreaweFAFASfwe/, name)
      result['public_id'].gsub!(/v6Ew3HmDAYfb3NMRdLxR45i_gXMbLlGyi/, "v#{Time.now.to_f}")
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

    def metadata(name)
      r = load_yaml('test/vcr/client/metadata.yml')
      result = JSON.parse(r['string'])
      # replace name and public_id by name argument
      result['id'] = name
      result['public_id'].gsub!(/bfdaf2b3-7ec5-41f4-9caa-d53247dd9666/, name)
      result
    end
    private

    def load_yaml filename
      path = "#{library_root}/#{filename}"
      YAML.load_file(path)['http_interactions'].first['response']['body']
    end

    def library_root
      @library_root ||= File.expand_path('../../../', __FILE__)
    end
  end
end
