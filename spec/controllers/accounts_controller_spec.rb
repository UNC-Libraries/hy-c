require 'rails_helper'

RSpec.describe AccountsController, type: :controller do
  let(:valid_attributes) {
    { onyen: 'new_test_person1' }
  }

  let(:invalid_attributes) {
    { onyen: 'admin' }
  }

  describe 'GET #new as admin' do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it 'returns http success' do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #new as non-admin' do
    it 'redirects to sign in page' do
      get :new
      expect(response).to have_http_status(:redirect)
      expect(response.header['Location']).to eq 'http://test.host/users/sign_in?locale=en'
    end
  end

  describe 'POST #create as admin' do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    context 'when user does not exist' do
      it 'creates a new User' do
        expect {
          post :create, params: { account: valid_attributes }
        }.to change(User, :count).by(1)
        expect(flash[:notice]).to eq "A user account for #{valid_attributes[:onyen]}@ad.unc.edu has been created."
      end

      it 'redirects to admin_users_path' do
        post :create, params: { account: valid_attributes }
        expect(response).to redirect_to('/admin/users?locale=en')
      end
    end

    context 'when user exists' do
      it 'redirects to admin_users_path' do
        post :create, params: { account: invalid_attributes }
        expect(response).to redirect_to('/admin/users?locale=en')
        expect(flash[:notice]).to eq "A user account for #{invalid_attributes[:onyen]}@ad.unc.edu already exists."
      end
    end
  end

  describe 'POST #create as non-admin' do
    it 'redirects to sign in page' do
      post :create, params: { account: valid_attributes }
      expect(response).to have_http_status(:redirect)
      expect(response.header['Location']).to eq 'http://test.host/users/sign_in?locale=en'
    end
  end
end
