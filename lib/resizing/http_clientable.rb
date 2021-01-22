# frozen_string_literal: true

module Resizing
  module HttpClientable
    def http_client
      @http_client ||= Faraday.new(url: config.host) do |builder|
        builder.options[:open_timeout] = config.open_timeout
        builder.options[:timeout] = config.response_timeout
        builder.request :multipart
        builder.request :url_encoded
        builder.adapter Faraday.default_adapter
      end
    end
  end
end
