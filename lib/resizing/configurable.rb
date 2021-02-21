# frozen_string_literal: true

module Resizing
  module Configurable
    def self.included mod
      mod.send(:attr_reader, :config)
    end

    def initialize_config *attrs
      config = if attrs.first.is_a? Configuration
                 attrs.first
               elsif attrs.first.nil?
                 Resizing.configure
               else
                 Configuration.new(*attrs)
               end

      instance_variable_set :@config, config
    end
  end
end
