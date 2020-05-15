# Resizing

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/resizing`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'resizing'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install resizing

## Usage

```
  # initialize client
  options = {
    project_id: '098a2a0d-0000-0000-0000-000000000000',
    secret_token: '4g1cshg......rbs6'
  }
  client = Resizing::Client.new(options)

  # upload image to resizing
  file = File.open('sample.jpg', 'r')
  response = client.post(file)
  => {
       "id"=>"a4ed2bf0-a4cf-44fa-9c82-b53e581cb469",
       "project_id"=>"098a2a0d-0000-0000-0000-000000000000",
       "content_type"=>"image/jpeg",
       "latest_version_id"=>"LJY5bxBF7Ryxfr5kC1F.63W8bzp3pcUm",
       "latest_etag"=>"\"190143614e6c342637584f46f18f8c58\"",
       "created_at"=>"2020-05-15T15:33:10.711Z",
       "updated_at"=>"2020-05-15T15:33:10.711Z",
       "url"=>"/projects/098a2a0d-0000-0000-0000-000000000000/upload/images/a4ed2bf0-a4cf-44fa-9c82-b53e581cb469"
     }

  name = response['url']
  # get transformation url
  name = response['url']
  transform = {width: 200, height: 300}

  transformation_url = Resizing.url(name, transform)
  => "https://www.resizing.net/projects/098a2a0d-0000-0000-0000-000000000000/upload/images/a4ed2bf0-a4cf-44fa-9c82-b53e581cb469/width_200,height_300"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jksy/resizing.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
