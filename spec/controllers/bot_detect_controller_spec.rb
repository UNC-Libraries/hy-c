# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BotDetectController, type: :controller do
  around do |example|
    # Default from bot_controller from class_attribute :cf_turnstile_secret_key
    ENV['CF_TURNSTILE_SECRET_KEY'] = '1x0000000000000000000000000000000AA'
    example.run
  end

  describe '#verify_challenge' do
    it 'handles turnstile success' do
      turnstile_response = stub_turnstile_success
      milliseconds_in_a_day = 86400000

      post :verify_challenge, params: { cf_turnstile_response: 'XXXX.DUMMY.TOKEN.XXXX' }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.to_json

      expect(session[BotDetectController.session_passed_key]).to be_present
      expect(session[BotDetectController.session_passed_key][:SESSION_IP_KEY]).to eq('0.0.0.0')
      expect(session[BotDetectController.session_passed_key][:SESSION_DATETIME_KEY].to_i).to be_within(milliseconds_in_a_day).of(Time.now.to_i)
    end

    it 'handles turnstile failure' do
      turnstile_response = stub_turnstile_failure

      post :verify_challenge, params: { cf_turnstile_response: 'XXXX.DUMMY.TOKEN.XXXX' }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.to_json

      expect(session[BotDetectController.session_passed_key]).not_to be_present
    end
  end
end
