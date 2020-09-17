module Resizing
  class PublicId
    def initialize public_id
      @public_id = public_id
    end

    def empty?
      @public_id.to_s.empty?
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

    def to_s
      @public_id.to_s
    end

    private

    def parsed
      return nil if @public_id.nil?
      @parsed ||= Resizing.separate_public_id(@public_id)
    end

    private
  end
end
