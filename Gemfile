source :rubygems
ruby "1.9.3"

gem 'sinatra'
gem 'heroku'
gem 'twilio-ruby'
gem 'pg'
gem 'data_mapper'
gem 'dm-postgres-adapter'
gem 'newrelic_rpm'

group :development do
  gem 'dm-sqlite-adapter'
end

group :test do
  gem 'rspec'
  gem 'guard-rspec'
  gem 'guard-bundler'
  gem 'rack-test', require: 'rack/test'
end

group :development, :test do
  gem 'pry'
end
