# frozen_string_literal: true

module Resizing
  class MockClient
    def post(file_or_binary, options = {})
      load_yaml('test/vcr/client/post.yml')
    end

    def put(name, file_or_binary, options)
      load_yaml('test/vcr/client/put.yml')
    end

    def delete(name)
      load_yaml('test/vcr/client/delete.yml')
    end

    private

    def load_yaml filename
      YAML.load_file(filename)['http_interactions'].first['response']['body']
    end
  end
end
