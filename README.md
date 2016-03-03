# Locomotivecms::Freight

Imports posts, comments and images from any WordPress site.  Rewrites image tags and internal links.

## Installation

This gem adds rake tasks to a LocomotiveCMS Wagon-generated project directory.

Add this line to your application's Gemfile:

```ruby
gem 'locomotivecms-freight'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install locomotivecms-freight

Finally, place this somewhere in your project's Rakefile:

```ruby
require 'locomotivecms/freight/tasks'
```

## Usage

First, on your WordPress site, log in as an admin user, and navigate to Tools -> Export.  Select
"All content" and click "Download Export File".  Save the file and remember the location.

Next, install the LocomotiveCMS content_types needed for WordPress posts and comments:

    bundle exec rake wp:install_content_types

Each post's body will be converted to markdown.  After this step, you will need to push the new
content types to each engine to which you will be deploying:

    bundle exec wagon sync production -v -r content_types

Now that we have the necessary content_types to receive them, we can import all posts, comments and
images from a WordPress site, run the following command:

    bundle exec rake wp:import TARGET=production XML=/path/to/my-wordpress-export.xml

Note that `TARGET` should reference one of the environments defined in your `config/deploy.yml` file.
Also be aware that image importing will not work unless the WordPress site from which you are exporting
is up and operational.  This is because the XML export file from a WordPress site contains pages, posts
and comments, but not other file resources such as images, audio/video files etc.

Also be aware that as of this writing, Freight's only concern is with posts and comments; it ignores
pages.

If there were images downloaded then you will need to push them up to your target LocomotiveCMS engine:

    bundle exec wagon sync production -v

To remove all _imported_ posts and associated comments, run this:

    bundle exec rake wp:clean TARGET=production

And finally, to remove all imported posts and associated comments and then re-import, do this:

    bundle exec rake wp:reload TARGET=production XML=/path/to/my-wordpress-export.xml

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joelhelbling/locomotivecms-freight.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

