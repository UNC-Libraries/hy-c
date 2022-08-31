# frozen_string_literal: true
require 'rails_helper'

RSpec.describe OmniauthController, type: :request do
  describe '#new' do
    context 'using database auth' do
      it 'is successful' do
        get new_user_session_path
        expect(response).to be_success
      end
    end

    context 'not using database auth' do
      around do |example|
        cached_database_auth = ENV['DATABASE_AUTH']
        ENV['DATABASE_AUTH'] = 'false'
        example.run
        ENV['DATABASE_AUTH'] = cached_database_auth
      end

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'is successful' do
        get new_user_session_path
        expect(response).to redirect_to "/Shibboleth.sso/Login?target=#{user_shibboleth_omniauth_callback_path}%26origin="
      end
    end
  end

  describe '#after_sign_out_path_for' do
    context 'using database auth' do
      it 'redirects to home page' do
        get destroy_user_session_path
        expect(response).to redirect_to root_path
        expect(flash[:notice]).to eq 'Signed out successfully.'
      end
    end

    context 'not using database auth' do
      around do |example|
        cached_database_auth = ENV['DATABASE_AUTH']
        cached_sso_logout_url = ENV['SSO_LOGOUT_URL']
        ENV['DATABASE_AUTH'] = 'false'
        ENV['SSO_LOGOUT_URL'] = 'https://shibboleth.example.com/idp/logout.jsp'
        example.run
        ENV['DATABASE_AUTH'] = cached_database_auth
        ENV['SSO_LOGOUT_URL'] = cached_sso_logout_url
      end

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'redirects to shibboleth logout url' do
        get destroy_user_session_path
        expect(response).to redirect_to 'https://shibboleth.example.com/idp/logout.jsp'
      end
    end
  end
end
