# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BotDetectController, type: :controller do
  around do |example|
    # Default from bot_controller from class_attribute :cf_turnstile_secret_key
    ENV['CF_TURNSTILE_SECRET_KEY'] = '1x0000000000000000000000000000000AA'
    example.run
  end

  describe '.challenge_download_request?' do
    let(:mock_request) do
      instance_double(ActionDispatch::Request,
                      query_parameters: {},
                      user_agent: 'Mozilla/5.0 (compatible; regular browser)'
      )
    end
    let(:mock_controller) { instance_double(Hyrax::DownloadsController, request: mock_request) }

    before do
      allow(BotDetectController).to receive(:challenge_downloads_enabled?).and_return(true)
      allow(mock_controller).to receive(:is_a?).with(Hyrax::DownloadsController).and_return(true)
    end

    it 'returns true for a normal download request' do
      expect(BotDetectController.send(:challenge_download_request?, mock_controller, mock_request)).to be true
    end

    it 'returns false for thumbnail requests' do
      allow(mock_request).to receive(:query_parameters).and_return({ 'file' => 'thumbnail' })
      expect(BotDetectController.send(:challenge_download_request?, mock_controller, mock_request)).to be false
    end

    it 'returns false for GoogleOther requests' do
      allow(mock_request).to receive(:user_agent).and_return('Mozilla/5.0 (compatible; GoogleOther/2.1; +http://www.google.com/bot.html)')
      expect(BotDetectController.send(:challenge_download_request?, mock_controller, mock_request)).to be false
    end

    it 'returns false when challenge downloads is not enabled' do
      allow(BotDetectController).to receive(:challenge_downloads_enabled?).and_return(false)
      expect(BotDetectController.send(:challenge_download_request?, mock_controller, mock_request)).to be false
    end

    it 'returns false for non-downloads controllers' do
      allow(mock_controller).to receive(:is_a?).with(Hyrax::DownloadsController).and_return(false)
      expect(BotDetectController.send(:challenge_download_request?, mock_controller, mock_request)).to be false
    end
  end

  describe '.challenge_downloads_enabled?' do
    it 'returns true when the Flipflop feature is enabled' do
      allow(Flipflop).to receive(:challenge_downloads?).and_return(true)
      expect(BotDetectController.send(:challenge_downloads_enabled?)).to be true
    end

    it 'returns true when the CF_CHALLENGE_DOWNLOADS env var is true' do
      allow(Flipflop).to receive(:challenge_downloads?).and_return(false)
      around_env = ENV['CF_CHALLENGE_DOWNLOADS']
      ENV['CF_CHALLENGE_DOWNLOADS'] = 'true'
      expect(BotDetectController.send(:challenge_downloads_enabled?)).to be true
    ensure
      ENV['CF_CHALLENGE_DOWNLOADS'] = around_env
    end

    it 'returns false when neither Flipflop nor env var is enabled' do
      allow(Flipflop).to receive(:challenge_downloads?).and_return(false)
      old = ENV.delete('CF_CHALLENGE_DOWNLOADS')
      expect(BotDetectController.send(:challenge_downloads_enabled?)).to be false
    ensure
      ENV['CF_CHALLENGE_DOWNLOADS'] = old if old
    end
  end

  describe '.env_flag_enabled?' do
    it 'returns true when the env var value is true (case-insensitive)' do
      original = ENV['CF_CHALLENGE_DOWNLOADS']
      ENV['CF_CHALLENGE_DOWNLOADS'] = 'TrUe'
      expect(BotDetectController.send(:env_flag_enabled?, 'CF_CHALLENGE_DOWNLOADS')).to be true
    ensure
      ENV['CF_CHALLENGE_DOWNLOADS'] = original
    end

    it 'returns false when the env var is missing' do
      original = ENV.delete('CF_CHALLENGE_DOWNLOADS')
      expect(BotDetectController.send(:env_flag_enabled?, 'CF_CHALLENGE_DOWNLOADS')).to be false
    ensure
      ENV['CF_CHALLENGE_DOWNLOADS'] = original if original
    end
  end

  describe '.not_thumbnail?' do
    it 'returns false when file param is thumbnail' do
      request = instance_double(ActionDispatch::Request, query_parameters: { 'file' => 'thumbnail' })
      expect(BotDetectController.send(:not_thumbnail?, request)).to be false
    end

    it 'returns true when file param is absent' do
      request = instance_double(ActionDispatch::Request, query_parameters: {})
      expect(BotDetectController.send(:not_thumbnail?, request)).to be true
    end
  end

  describe '.not_googlebot?' do
    it 'returns true for a regular browser user agent' do
      request = instance_double(ActionDispatch::Request, user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)')
      expect(BotDetectController.send(:not_googlebot?, request)).to be true
    end

    it 'returns false for a GoogleOther user agent' do
      request = instance_double(ActionDispatch::Request, user_agent: 'Mozilla/5.0 (compatible; GoogleOther/2.1; +http://www.google.com/bot.html)')
      expect(BotDetectController.send(:not_googlebot?, request)).to be false
    end

    it 'returns true when user agent is nil' do
      request = instance_double(ActionDispatch::Request, user_agent: nil)
      expect(BotDetectController.send(:not_googlebot?, request)).to be true
    end
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
