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
  video_host: 'https://video.resizing.net',
  project_id: 'your-project-id',
  secret_token: 'your-secret-token'
}
```

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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jksy/resizing-gem.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
