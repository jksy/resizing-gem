# frozen_string_literal: true

require 'resizing/carrier_wave/callback_file'
require 'resizing/carrier_wave/storage/file'
require 'resizing/carrier_wave/storage/remote'

module Resizing
  # rubocop:disable Metrics/ModuleLength
  module CarrierWave
    BLANK_ASSIGNMENT_MESSAGE = '[resizing] Assigning nil or an empty string to a column with an image ' \
                               'keeps the image on CarrierWave 2.x, but deletes it on CarrierWave 3.x ' \
                               'as plain CarrierWave does. Use remove_<column>! to delete the image, ' \
                               'or do not assign the column to keep it.'

    class Railtie < ::Rails::Railtie
      # Railtie skelton codes
      rake_tasks do
        # NOP
      end

      config.after_initialize do |app|
        # NOP
      end

      ActiveSupport.on_load(:active_record) do
        # NOP
      end
    end

    def self.included(base)
      base.storage Resizing::CarrierWave::Storage::Remote
      base.extend ClassMethods
    end

    def initialize(*args)
      @requested_format = nil
      @default_format = nil
      @retrieved_identifier = nil
      super
    end

    # Override to store the identifier and set up @file for later use
    def retrieve_from_store!(identifier)
      @retrieved_identifier = identifier
      super
      # Ensure @file is set up so that remove! can call @file.delete
      file
    end

    # CarrierWave 3.x reads #path of the removed uploaders again after commit
    # (Mounter#remove_previous), and #file would retrieve the deleted image from the
    # identifier and delete it again, so the identifier is dropped with the image.
    def remove!
      super
      @retrieved_identifier = nil
      @identifier = nil
    end

    def file
      file_identifier = @retrieved_identifier || @identifier || read_column

      return nil if file_identifier.blank?

      @file ||= Resizing::CarrierWave::Storage::File.new(self)
      @file.retrieve(file_identifier)
      @file
    end

    def url(*args)
      return default_url unless read_column.present?

      transforms = args.map do |version|
        version = version.intern
        raise "No version is found: #{version}, #{versions.keys} are exists." unless versions.key? version

        versions[version].transform_string
      end.compact

      "#{build_url}/#{transforms.join('/')}"
    end

    def read_column
      model.read_attribute(serialization_column)
    end

    def build_url
      "#{Resizing.configure.image_host}#{model.read_attribute(serialization_column)}"
    end

    # need override this. if you want to return some url when target_column is nil
    def default_url
      nil
    end

    def transform_string
      transforms = processors.map do |processor|
        transform_string_from processor
      end

      transforms.join('/')
    end

    def rename
      raise NotImplementedError, 'rename is not implemented'
    end

    def resize_to_limit(*args)
      @transform ||= []
      @transform.push(:resize_to_limit, *args)
    end

    def resize_to_fill(*args)
      @transform ||= []
      @transform.push(:resize_to_fill, *args)
    end

    def resize_to_fit(*args)
      @transform ||= []
      @transform.push(:resize_to_fit, *args)
    end

    # Resizing has no cache storage, so the file is uploaded to Resizing here as a
    # temporary image instead of being copied to a local workfile. The temporary image
    # is confirmed by #store! when the model is saved (after commit with ActiveRecord);
    # when the model is never saved, e.g. on a validation error, Resizing deletes it at
    # its expires_at (see #cache_expires_in).
    #
    # The :cache callbacks are still run, so that the uploader settings hooked on them
    # (extension_allowlist / extension_denylist / content_type_allowlist /
    # content_type_denylist / size_range) are honoured before the upload happens.
    # The callbacks that do not fit the Resizing flow (process! and cache_versions!)
    # are disabled below.
    def cache!(new_file)
      if new_file.nil?
        warn_blank_assignment
        return
      end

      # CallbackFile responds to #extension / #content_type / #size, which the
      # before :cache callbacks need, with the extension derived from the content type
      # (see CallbackFile). The original object is handed to the storage, because it
      # carries the original filename sent to Resizing.
      sanitized = CallbackFile.new(new_file)
      return if sanitized.empty?

      with_callbacks(:cache, sanitized) do
        file = storage.cache!(new_file)
        # The public id of the temporary image serves as the cache id, so that
        # store! confirms it and #cache_name can restore it.
        @cache_id = file.public_id.to_s
        @staged = true
        @filename = file.public_id.to_s
        @file = file
      end
    end

    # The public id of the temporary image while it is cached, nil otherwise.
    # It is what `<column>_cache` returns, to be sent back with a form that is shown
    # again (e.g. on a validation error) so that the image need not be uploaded again.
    def cache_name
      @cache_id
    end

    # Restores the temporary image from its cache name (see #cache_name).
    #
    # The cache name comes from the request, so only a temporary image of the
    # configured project that has not expired is accepted; a confirmed image, which
    # may belong to another record, must not be attached through it. Anything else
    # raises CarrierWave::InvalidParameter, which CarrierWave ignores as it does an
    # invalid cache name.
    def retrieve_from_cache!(cache_name)
      warn_blank_assignment if cache_name.blank?
      with_callbacks(:retrieve_from_cache, cache_name) do
        public_id = temporary_public_id_from(cache_name)
        @cache_id = public_id
        @staged = true
        @file = storage.retrieve_from_cache!(public_id)
        model.send :write_attribute, serialization_column, public_id
      end
    end

    # Seconds until a temporary image uploaded by #cache! expires. nil uses the default
    # of Resizing. Override this to change it, e.g. when a form may be kept open for a
    # long time before it is submitted.
    def cache_expires_in
      nil
    end

    # The file cached by #cache! is the temporary image, which becomes the stored image
    # when it is confirmed, so it must not be deleted after storing it.
    def delete_tmp_file_after_storage
      false
    end

    # process! is called before :cache
    # Disable on Resizing, because `process` is repurposed as a definition of the
    # transformation applied when the browser fetches the image URL (see #transform_string),
    # so the processors must not be run as actual image processing on upload.
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/processing.rb#L12
    def process!(*args)
      # NOP
    end

    # cache_versions! is called after :cache
    # Disable on Resizing, because each version would upload the same image again and
    # the resulting public_id would be stored nowhere, leaving orphan images behind.
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L17
    def cache_versions!(*args)
      # NOP
    end

    # retrieve_versions_from_cache! is called after :retrieve_from_cache
    # Disable on Resizing, because the versions have no image of their own; each version
    # would only look up the same temporary image again.
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L20
    def retrieve_versions_from_cache!(*args)
      # NOP
    end

    def filename
      read_column
    end

    def serialization_column
      model.send(:_mounter, mounted_as).send(:serialization_column)
    end

    # store_versions! is called after store!
    # Disable on Resizing, because transform the image when browser fetch the image URL
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L18
    def store_versions!(*args)
      # NOP
    end

    # store_versions! is called after delete
    # Disable on Resizing, because transform the image when browser fetch the image URL
    # https://github.com/carrierwaveuploader/carrierwave/blob/28190e99299a6131c0424a5d10205f471e39f3cd/lib/carrierwave/uploader/versions.rb#L18
    def remove_versions!(*args)
      # NOP
    end

    # deduplicate is called by CarrierWave 3.x before saving, and appends "(2)" to the
    # identifier when it equals one of the replaced images.
    # Disable on Resizing, because the identifier is the public id given by Resizing,
    # which must be written to the column as is.
    def deduplicate(*args)
      # NOP
    end

    def requested_format
      # TODO
      # The request with uploading format parameter is not working on the Resizing until 2020/09/25
      @requested_format
    end

    def default_format
      @default_format
    end

    def format
      requested_format || default_format
    end

    module ClassMethods
    end

    private

    # On CarrierWave 2.x, #filename (the column) is the identifier of the blank uploader
    # made for nil / '', so the column and the image are kept, unlike plain CarrierWave.
    # CarrierWave 3.x does not read #filename there and deletes the image.
    def warn_blank_assignment
      return if carrierwave3?
      return if read_column.blank?

      warn BLANK_ASSIGNMENT_MESSAGE
    end

    def carrierwave3?
      Gem::Version.new(::CarrierWave::VERSION) >= Gem::Version.new('3')
    end

    def temporary_public_id_from(cache_name)
      public_id = begin
        Resizing::PublicId.new(cache_name)
      rescue StandardError
        nil
      end
      raise_invalid_cache_name if public_id.nil? || public_id.empty? ||
                                  public_id.project_id != Resizing.configure.project_id

      # Resizing answers 404 for an expired temporary image even before deleting it
      metadata = Resizing.metadata(public_id.image_id, {})
      raise_invalid_cache_name unless metadata['temporary'] == true && metadata['public_id'].present?

      metadata['public_id']
    end

    def raise_invalid_cache_name
      raise ::CarrierWave::InvalidParameter, 'invalid cache name'
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def transform_string_from(processor)
      action = processor.first
      value = processor.second

      case action
      when :resize_to_fill, :resize_to_limit, :resize_to_fit
        name = action.to_s.gsub(/resize_to_/, '')
        { c: name, w: value.first, h: value.second }
      when :transformation
        result = {}
        result[:q] = value[:quality] if value[:quality]
        result[:f] = value[:fetch_format] if value[:fetch_format]
        result[:f] = value[:format] if value[:format]
        result
      else
        raise NotImplementedError, "#{action} is not supported. #{processor.inspect}"
      end.map do |key, value|
        next nil if value.nil?

        "#{key}_#{value}"
      end.compact.join(',')
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  end
  # rubocop:enable Metrics/ModuleLength
end
