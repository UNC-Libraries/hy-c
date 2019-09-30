require 'rails_helper'

RSpec.describe MastersPapersController, type: :controller do

  describe "GET #department" do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false)}
    end
    
    before do
      sign_in user
    end
    
    it "returns http success" do
      get :department
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #select_department' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false)}
    end

    let(:masters_paper_params) { {masters_paper: {affiliation: 'Physician Assistant Program'}} }

    before do
      sign_in user
    end

    it 'redirects to the form for creating a new masters paper' do
      post :select_department, params: masters_paper_params
      expect(response).to redirect_to '/concern/masters_papers/new?affiliation=Physician+Assistant+Program&locale=en'
    end
  end
end
