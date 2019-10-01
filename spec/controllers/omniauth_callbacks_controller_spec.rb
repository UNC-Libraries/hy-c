require 'rails_helper'

RSpec.describe OmniauthCallbacksController, type: :request do
  # method from omniauth-shibboleth spec/omniauth/strategies/shibboleth_spec.rb for building a session
  def make_env(path = '/auth/shibboleth', props = {})
    {
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => path,
        'rack.session' => {},
        'rack.input' => StringIO.new('test=true')
    }.merge(props)
  end

  describe '#shibboleth' do
    let(:app){ Rack::Builder.new do |b|
      b.use Rack::Session::Cookie, {:secret => "abc123"}
      b.use OmniAuth::Strategies::Shibboleth
      b.run lambda{|env| [200, {}, ['Not Found']]}
    end.to_app }
    let(:strategy) { OmniAuth::Strategies::Shibboleth.new(app, {}) }

    it 'is expected to set default omniauth.auth fields' do
      dummy_id = 'abcdefg'
      eppn = 'test@example.com'
      display_name = 'Test User'
      env = make_env('/users/auth/shibboleth/callback', 'Shib-Session-ID' => dummy_id, 'eppn' => eppn, 'displayName' => display_name)
      strategy.call!(env)
      expect(strategy.env['omniauth.auth']['uid']).to eq(eppn)
      expect(strategy.env['omniauth.auth']['info']['name']).to eq(display_name)
    end
  end

  describe '#failure' do
    it 'is successful' do
      # failure method called when shibboleth callback is not successful
      get user_shibboleth_omniauth_callback_path
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to eq 'Could not authenticate you from Shibboleth because "No shibboleth session".'
    end
  end
end
