# Resizing

[![Gem Version](https://img.shields.io/gem/v/resizing.svg)](https://rubygems.org/gems/resizing)
[![test](https://github.com/jksy/resizing-gem/actions/workflows/test.yml/badge.svg)](https://github.com/jksy/resizing-gem/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/jksy/resizing-gem/graph/badge.svg)](https://codecov.io/gh/jksy/resizing-gem)

Client and utilities for [Resizing](https://www.resizing.net/) - an image hosting and transformation service.

## Requirements

- Ruby 3.1.0 or later

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'resizing'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install resizing

## Configuration

```ruby
Resizing.configure = {
  image_host: 'https://img.resizing.net',
  project_id: 'your-project-id',
  secret_token: 'your-secret-token'
}
```

`video_host` は動画 API の廃止にともない非推奨です。指定しても利用されず、`Configuration#video_host` や `Configuration::DEFAULT_VIDEO_HOST` を参照すると警告が出ます。将来のバージョンで削除します。

## Usage

### Basic Client Usage

```ruby
# Initialize client
client = Resizing::Client.new

# Upload image to resizing
file = File.open('sample.jpg', 'r')
response = client.post(file)
# => {
#      "id"=>"a4ed2bf0-a4cf-44fa-9c82-b53e581cb469",
#      "project_id"=>"098a2a0d-0000-0000-0000-000000000000",
#      "content_type"=>"image/jpeg",
#      "latest_version_id"=>"LJY5bxBF7Ryxfr5kC1F.63W8bzp3pcUm",
#      "latest_etag"=>"\"190143614e6c342637584f46f18f8c58\"",
#      "created_at"=>"2020-05-15T15:33:10.711Z",
#      "updated_at"=>"2020-05-15T15:33:10.711Z",
#      "url"=>"/projects/098a2a0d-0000-0000-0000-000000000000/upload/images/a4ed2bf0-a4cf-44fa-9c82-b53e581cb469"
#    }

# Generate transformation URL
image_id = response['id']
transformation_url = Resizing.url_from_image_id(image_id, nil, ['w_200', 'h_300'])
# => "https://img.resizing.net/projects/.../upload/images/.../w_200,h_300"
```

### CarrierWave Integration

```ruby
class ImageUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  version :list_smallest do
    process resize_to_fill: [200, 200]
  end
end

class User
  mount_uploader :image, ImageUploader
end
```

## Development

### Dev Container (recommended)

This repository ships a [Dev Container](https://containers.dev/) so that everyone develops
against the same Ruby / MySQL setup.

Requirements: Docker and either VS Code + the *Dev Containers* extension, or the
[`devcontainer` CLI](https://github.com/devcontainers/cli).

1. Open the repository in VS Code and run **Dev Containers: Reopen in Container**
   (or run `devcontainer up --workspace-folder .`).
2. `bundle install` and the MySQL wait are executed automatically by
   `.devcontainer/post-create.sh`.
3. Inside the container:

   ```console
   $ bundle exec rake test    # run the tests
   $ bundle exec rubocop      # run the linter
   $ bin/console              # interactive prompt
   ```

The container provides:

- Ruby managed by [rbenv](https://github.com/rbenv/rbenv), so the version can be changed
  from inside the container (see below)
- MySQL 5.7 with the `resizing_gem_test` database, matching CI
- `RAILS_VERSION` (default `7.0`) to test against another Rails version, matching the
  `RAILS_VERSION` switch in the `Gemfile` and in CI

Gems are installed into a named volume (`/usr/local/bundle`). `vendor/`, `.bundle/` and
`.ruby-lsp/` are kept on their own volumes so that Ruby artifacts generated on the host do
not leak into the container through the bind mount: `vendor/` holds gems whose native
extensions are built against the host's libraries, `.bundle/config` points `BUNDLE_PATH`
at it, and `.ruby-lsp/` records which gems the Ruby LSP extension has installed. The host
copies are left untouched.

#### Changing the Ruby version

Ruby 3.1.7 is installed when the image is built, and `.ruby-version` is honoured on
container creation. To switch to another version from inside the container:

```console
$ rbenv install 3.3.12
$ rbenv local 3.3.12    # writes .ruby-version (gitignored)
$ bundle install
```

`rbenv install` needs no `sudo`; the build dependencies are already in the image. To
change the version the image ships with, set the `RUBY_VERSION` build arg in
`.devcontainer/compose.yaml` and rebuild.

### Without a Dev Container

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

The tests need a MySQL server. `docker-compose.yml` in the repository root starts a
suitable one (`docker compose up -d mysql`). The connection settings default to
`root:secret@127.0.0.1:3306/resizing_gem_test` and can be overridden with the
`MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_DATABASE`, `MYSQL_USER` and `MYSQL_PASSWORD`
environment variables.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jksy/resizing-gem.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
