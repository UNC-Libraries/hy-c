require 'rails_helper'

RSpec.describe AccountsController, type: :controller do

  let(:valid_attributes) {
    {email: 'new_test_person1'}
  }

  let(:invalid_attributes) {
    {email: 'admin'}
  }

  describe "GET #new" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    context "when user does not exist" do
      it "creates a new User" do
        expect {
          post :create, params: {account: valid_attributes}
        }.to change(User, :count).by(1)
      end

      it "redirects to admin_users_path" do
        post :create, params: {account: valid_attributes}
        expect(response).to redirect_to('/admin/users?locale=en')
      end
    end

    context "when user exists" do
      it "redirects to admin_users_path" do
        post :create, params: {account: invalid_attributes}
        expect(response).to redirect_to('/admin/users?locale=en')
      end
    end
  end
end
