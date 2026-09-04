# frozen_string_literal: true

module Resizing
  class PublicId
    def initialize(public_id)
      @public_id = public_id
      parsed
    end

    # nil / 空文字 / 空白のみの文字列はいずれも「値なし」として扱う
    def empty?
      @public_id.to_s.strip.empty?
    end

    def image_id
      parsed[:image_id] if parsed
    end

    def project_id
      parsed[:project_id] if parsed
    end

    def version
      parsed[:version] if parsed
    end

    # temporary
    def filename
      image_id
    end

    def identifier
      "/projects/#{project_id}/upload/images/#{image_id}"
    end

    def to_s
      @public_id.to_s
    end

    private

    def parsed
      return nil if empty?

      unless defined? @parsed
        @parsed = Resizing.separate_public_id(@public_id)
        raise "type error #{@public_id}" if @parsed.nil?
      end
      @parsed
    end
  end
end
