# frozen_string_literal: true

module Resizing
  module CarrierWave
    # The file handed to CarrierWave's :cache callbacks (extension_allowlist /
    # extension_denylist / content_type_allowlist / content_type_denylist / size_range).
    #
    # The extension used by the callbacks is derived from the content type whenever the
    # content type is known, instead of being taken from the file name as plain
    # CarrierWave does.
    #
    # A file downloaded from a Resizing URL (e.g. when it is assigned through
    # `remote_<column>_url=`) is the typical case: the last segment of the URL is the
    # version string (`.../images/<image_id>/v<version>`), which contains dots, so the
    # "extension" CarrierWave finds in the file name is a meaningless part of the version
    # (`Fv_Q` for `/v0cRq7Yb2mZt9LxA3wN8eKd5pHs1.Fv_Q`), and extension_allowlist would
    # reject every such file. The HTTP response carries the real content type, so it is
    # the reliable source.
    #
    # When the content type is unknown (`application/octet-stream`, or a type that no
    # extension is registered for), the file name is used as is, as in plain CarrierWave.
    class CallbackFile < ::CarrierWave::SanitizedFile
      # Content type given to files whose real type could not be determined.
      # Carries no information about the extension, so it is treated as unknown.
      UNKNOWN_CONTENT_TYPE = 'application/octet-stream'

      def original_filename
        name = super
        return name if name.nil?

        extension = extension_for_content_type
        return name if extension.nil?

        basename, current_extension = split_extension(name)
        return name if extensions_for_content_type.include?(current_extension.downcase)

        "#{basename}.#{extension}"
      end

      private

      # The preferred extension of the content type, or nil when the content type is unknown.
      def extension_for_content_type
        extensions_for_content_type.first
      end

      # Every extension registered for the content type (lower case), or [] when unknown.
      # Neither library raises on an unregistered or malformed content type: MIME::Types
      # returns an empty list and MiniMime returns nil.
      #
      # MIME::Types (a dependency of CarrierWave 1.x and of fog) is preferred because it
      # knows every alias of an extension (jpeg / jpg / jpe for image/jpeg); MiniMime
      # (a dependency of CarrierWave 2.x+) knows only one extension per content type.
      def extensions_for_content_type
        @extensions_for_content_type ||= begin
          # Drop the parameters (`image/jpeg; charset=binary`), which MiniMime cannot handle
          type = content_type.to_s.split(';').first.to_s.strip.downcase
          if type.empty? || type == UNKNOWN_CONTENT_TYPE
            []
          else
            lookup_extensions(type)
          end
        end
      end

      def lookup_extensions(type)
        if defined?(::MIME::Types)
          ::MIME::Types[type].flat_map(&:extensions).map(&:downcase).uniq
        elsif defined?(::MiniMime)
          [::MiniMime.lookup_by_content_type(type)&.extension].compact.map(&:downcase)
        else
          []
        end
      end
    end
  end
end
