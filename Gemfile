Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

source 'https://rubygems.org'

ruby '2.1.0'

gem 'rails', '3.2.17'

gem 'pg'
#gem 'sqlite3'

# Gems used only for assets and not required in production environments by default.
group :assets do
  gem 'sass', '~> 3.2.5' # Sass is locked for now because of this bug: https://github.com/sass/sass/issues/1028. Remove this line at some point.
  gem 'sass-rails', '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer'

  gem 'uglifier', '>= 1.0.3'
  gem 'jquery-ui-rails', '~> 4.2.0'
end

group :test, :development do
  gem 'rspec-rails', '~> 3.4'
  gem 'shoulda'
  gem 'capybara'
  gem 'capybara-webkit'
end

gem 'jquery-rails', '~> 3.1.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

gem 'authlogic'
gem 'scrypt'
gem 'cancan'

# gem 'delayed_job', '~> 3.0.0'
gem 'delayed_job_active_record', '~> 4.0.0'

gem 'daemons'
gem 'rest_client', '1.8.0'

#gem 'paypal-sdk-core' # , :git => 'https://github.com/paypal/sdk-core-ruby.git'
gem 'paypal-sdk-rest'
gem 'ims-lti'
