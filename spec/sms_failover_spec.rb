require 'spec_helper'
require 'json'

describe "SMS Failover" do
  subject { last_response }

  context 'GET /queue (json)' do
    it "provides a list of sms messages in the queue" do
      3.times { |n| create_message("coca-cola-#{n}") }
      create_message('already seen').update(marked: true)

      get_json '/queue'
      JSON::parse(last_response.body).should have(3).items
    end
  end

  context 'POST /mark' do
    before(:each) do
      @messages = []
      3.times { |n| @messages << create_message }
      ENV['SMS_FAILOVER_TOKEN'] = 'test'
      post_json '/mark', {marked: (@messages.map &:id), token: 'test'}
    end

    it "marks messages ready for sweeping" do
      last_response.should be_ok
      @messages.map(&:id).each do |m_id|
        SmsMessage.get(m_id).marked.should be_true
      end
    end

  end

  context 'POST /sweep' do
    before(:each) do
      unmarked_message = create_message
      marked_message = create_message 
      marked_message.update(:marked => true)
      ENV['SMS_FAILOVER_TOKEN'] = 'test'
    end

    context "(auth'd)" do
      it "succeeds" do
        put_json '/sweep', {token: 'test'}
        last_response.should be_ok
      end

      it "clears the queue" do
        expect { 
          put_json '/sweep', {token: 'test'}
        }.to change {SmsMessage.count}.by(-1)
      end
    end

    context "(not auth'd)" do
      it "fails" do
        put_json '/sweep'
        last_response.should be_forbidden
      end

      it "doesn't clear the queue" do
        expect { 
          put_json '/sweep' 
        }.not_to change {SmsMessage.count}
      end
    end
  end
  
  context 'POST /sms-event' do
    it "adds a message to the queue" do
      Twilio::Util::RequestValidator.any_instance.stub(:validate) { true } 
      expect { 
        post '/sms-event', {From: "1234", Body: '1234'}, {'HTTP_ACCEPT' => 'application/xml'}
      }.to change{SmsMessage.count}.by(1)
    end
    it "rejects messages not from twilio" do
      Twilio::Util::RequestValidator.any_instance.stub(:validate) { false } 
      expect { 
        post '/sms-event', {From: "1234", Body: '1234'}, {'HTTP_ACCEPT' => 'application/xml'}
      }.not_to change{SmsMessage.count}
    end
  end
end

def create_message(text = "TEST")
  SmsMessage.create(from: "1231231234",
                    body: text,
                    received_at: Time.now())
end

def get_json(path)
  get path, {}, {'HTTP_ACCEPT' => 'application/json'}
end

def put_json(path, options = {})
  put path, options, {'HTTP_ACCEPT' => 'application/json'}
end

def post_json(path, options = {})
  post path, options, {'HTTP_ACCEPT' => 'application/json'}
end
