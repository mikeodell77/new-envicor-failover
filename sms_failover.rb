require 'sinatra'
require 'data_mapper'
require 'twilio-ruby'

class SmsMessage 
  include DataMapper::Resource
  property :id,          Serial
  property :from,        String, required: true
  property :body,        String, required: true
  property :received_at, DateTime, required: true
  property :marked,   Boolean, default: false
end

configure do
  DataMapper.setup(:default,(ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/development.sqlite3"))
  DataMapper.auto_upgrade!
  require 'newrelic_rpm'
end

set :logger, true

get '/ping' do
  [200, "OK"]
end

get '/queue', :provides => :json do
  [200, SmsMessage.all(marked: false).to_json]
end

post '/mark', :provides => :json do
  if request_from_stats?(params)
    marked_ids, failed_ids = [],[]
    params['marked'].each do |r|
      SmsMessage.get(r.to_i).update(:marked => true) ?
        marked_ids << r :
        failed_ids << r
    end if params['marked']
    [200, {
            marked: marked_ids, 
            failed: failed_ids,
            status: (failed_ids.empty? ? 'OK' : 'errors')
          }.to_json]
  else
    forbidden!
  end
end

put '/sweep', :provides => :json do
  if request_from_stats?(params)
    SmsMessage.all(:marked => true).destroy
    [200, "queue-cleared"]
  else
    forbidden!
  end
end

post '/sms-event' do
  if request_from_twilio?(request, params)
    # record incoming messages
    SmsMessage.create(from: params["From"], 
                      body: params["Body"], 
                      received_at: Time.now()) ?
      [200, [Twilio::TwiML::Response.new.text]] :
      [500, "Failed to store '#{params['Body']}' from #{params['From']}"]
  else
    forbidden!
  end
end

post '/new_board_event' do
  SmsMessage.create(from: params["From"],
                    body: params["Body"],
                    received_at: Time.now()) ?
    [200, "Success"] :
    [500, "Failed to store '#{params['Body']}' from #{params['From']}"]
end

def request_from_twilio?(request, params)
  return true if development?
  signature = request.env["HTTP_X_TWILIO_SIGNATURE"]
  validator = Twilio::Util::RequestValidator.new(ENV['TWILIO_AUTH_TOKEN'])
  validator.validate(ENV['TWILIO_FAILOVER_URL'],params,signature)
end

def request_from_stats?(params)
  ENV['SMS_FAILOVER_TOKEN'] == params['token']
end

def forbidden!
  [403, "Forbidden"]
end
