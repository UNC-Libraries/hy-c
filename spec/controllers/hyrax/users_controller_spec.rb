# frozen_string_literal: true
require 'rails_helper'

# test overridden actions
RSpec.context Hyrax::UsersController, type: :request do
  let(:user) { FactoryBot.create(:user) }

  let(:admin_user) { FactoryBot.create(:admin) }

  describe '#index' do
    context 'when not logged in' do
      it 'redirects to login page' do
        get hyrax.users_path
        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when non-admin is logged in' do
      before do
        sign_in user
      end

      it 'shows a list of users' do
        get hyrax.users_path
        expect(response).to be_success
        expect(response.body).to match 'Carolina Digital Repository Users'
      end
    end

    context 'when admin is logged in' do
      before do
        sign_in admin_user
      end

      it 'shows a list of users' do
        get hyrax.users_path
        expect(response).to be_success
        expect(response.body).to match 'Carolina Digital Repository Users'
      end
    end
  end

  describe '#show' do
    context 'when not logged in' do
      it 'redirects to the home page' do
        get hyrax.user_path(id: user.uid)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when non-admin is logged in' do
      before do
        sign_in user
      end

      it 'redirects to the home page' do
        get hyrax.user_path(id: user.uid)
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end

    context 'when admin is logged in' do
      before do
        sign_in admin_user
      end

      it 'shows a user profile' do
        get hyrax.user_path(id: user.uid)
        expect(response).to be_success
        expect(response.body).to include('has no highlighted works')
      end
    end
  end
end
