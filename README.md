# Install Ruby environment
```sh
sudo aptitude install ruby2.1.9
sudo gem install rake
sudo gem install bundler
```


# Install Rubyric

### Install gems
```sh
bundle install
```

### Configure
```sh
cp config/initializers/secret_token.rb.base config/initializers/secret_token.rb
cp config/initializers/settings.rb.base config/initializers/settings.rb
cp config/database.yml.base config/database.yml
```

### Create database, and put password and username to config/database.yml
```sh
sudo -u postgres createdb -O my_username rubyric
```

### Initialize database
```sh
rake db:setup
```

### Start server
```sh
bundle exec rails server
```
