require File.join(File.dirname(__FILE__), '..', 'sms_failover.rb')

require 'rspec'
require 'rack/test'

set :environment,  :test

RSpec.configure do |c|
  c.include Rack::Test::Methods
  c.after(:each) { SmsMessage.destroy }
end

def app
  Sinatra::Application
end
