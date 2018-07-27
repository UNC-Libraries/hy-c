require 'rails_helper'

RSpec.describe MastersPapersController, type: :controller do

  describe "GET #department" do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end
    
    before do
      sign_in user
    end
    
    it "returns http success" do
      get :department
      expect(response).to have_http_status(:success)
    end
  end

end
