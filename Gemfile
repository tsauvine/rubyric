Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

source 'https://rubygems.org'

ruby '2.4.0'

gem 'rails', '5.0.2'

gem 'puma', '~> 3.0'

gem 'pg'

# Gems used only for assets and not required in production environments by default.

gem 'sass' # Sass is locked for now because of this bug: https://github.com/sass/sass/issues/1028. Remove this line at some point.
gem 'sass-rails', '~> 5.0.6'
gem 'coffee-rails', '~> 4.2.1'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', '~> 0.12.3'

gem 'uglifier', '~> 3.0.4'
gem 'jquery-ui-rails', '~> 4.2.0'


group :development, :test do
  gem 'rspec-rails'
  gem 'shoulda'
  gem 'capybara'
  gem 'capybara-webkit'

  gem 'byebug', platform: :mri
  #gem 'sqlite3'
end

group :development do
  gem 'web-console'
  gem 'listen', '~> 3.0.5'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

gem 'jquery-rails', '~> 4.2.2'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

gem 'json', '2.0.3' # For Ruby 2.3 compatibility

gem 'authlogic'
gem 'scrypt'
gem 'cancan'

# gem 'delayed_job', '~> 3.0.0'
gem 'delayed_job_active_record', '~> 4.1.0'

gem 'daemons'
gem 'rest_client', '1.8.0'

#gem 'paypal-sdk-core' # , :git => 'https://github.com/paypal/sdk-core-ruby.git'
gem 'paypal-sdk-rest'
gem 'ims-lti'
