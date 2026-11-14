# frozen_string_literal: true

# A minimal Rails application that mounts a Resizing uploader the way README.md
# shows ("Making uploads work across form redisplays"), so that the integration
# with the view helpers, strong parameters and controllers is tested on every
# Rails version in CI.
#
# ActiveRecord is not loaded as a railtie: test_helper.rb has already connected
# to the test database, and the railtie would connect again from its own config.
require 'action_controller/railtie'
require 'action_view/railtie'

class ResizingRailsApp < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = 'resizing-rails-app-secret-key-base'
  # Integration tests request www.example.com, which the development defaults block
  config.hosts.clear
  config.action_controller.allow_forgery_protection = false
  # Raise errors in the tests instead of rendering an error page
  config.action_dispatch.show_exceptions = Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR.zero? ? false : :none
end

ResizingRailsApp.initialize!

ResizingRailsApp.routes.draw do
  resources :users, only: %i[new create show]
  post '/users_without_cache' => 'users_without_cache#create'
end

ActiveRecord::Schema.define do
  self.verbose = false

  connection.execute 'drop table if exists users'
  create_table :users do |t|
    t.string :name
    t.string :image
  end
end

class ImageUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave
end

class User < ActiveRecord::Base
  mount_uploader :image, ImageUploader

  validates :name, presence: true
end

class ApplicationController < ActionController::Base; end

class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to @user
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    head :ok
  end

  private

  def user_params
    params.require(:user).permit(:name, :image, :image_cache)
  end
end

# The same controller with <column>_cache left out of the strong parameters
class UsersWithoutCacheController < UsersController
  private

  def user_params
    params.require(:user).permit(:name, :image)
  end
end
