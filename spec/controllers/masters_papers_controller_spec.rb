require 'rails_helper'

RSpec.describe MastersPapersController, type: :controller do

  describe "GET #department" do
    it "returns http success" do
      get :department
      expect(response).to have_http_status(:success)
    end
  end

end
