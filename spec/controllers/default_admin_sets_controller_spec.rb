require 'rails_helper'

RSpec.describe DefaultAdminSetsController, type: :controller do

  # This should return the minimal set of attributes required to create a valid
  # DefaultAdminSet. As you add validations to DefaultAdminSet, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    {work_type_name: 'an admin set', admin_set_id: 'id123456'}
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # DefaultAdminSetsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET #index" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it "returns a success response" do
      default_admin_set = DefaultAdminSet.create! valid_attributes
      get :index, params: {}, session: valid_session
      expect(response).to be_success
    end
  end

  describe "GET #new" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it "returns a success response" do
      get :new, params: {}, session: valid_session
      expect(response).to be_success
    end
  end

  describe "GET #edit" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it "returns a success response" do
      default_admin_set = DefaultAdminSet.create! valid_attributes
      get :edit, params: {id: default_admin_set.to_param}, session: valid_session
      expect(response).to be_success
    end
  end

  describe "POST #create" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    context "with valid params" do
      it "creates a new DefaultAdminSet" do
        expect {
          post :create, params: {default_admin_set: valid_attributes}, session: valid_session
        }.to change(DefaultAdminSet, :count).by(1)
      end

      it "redirects to the created default_admin_set" do
        post :create, params: {default_admin_set: valid_attributes}, session: valid_session
        expect(response).to redirect_to(DefaultAdminSet.last)
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e. to display the 'new' template)" do
        post :create, params: {default_admin_set: invalid_attributes}, session: valid_session
        expect(response).to be_success
      end
    end
  end

  describe "PUT #update" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    context "with valid params" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested default_admin_set" do
        default_admin_set = DefaultAdminSet.create! valid_attributes
        put :update, params: {id: default_admin_set.to_param, default_admin_set: new_attributes}, session: valid_session
        default_admin_set.reload
        skip("Add assertions for updated state")
      end

      it "redirects to the default_admin_set" do
        default_admin_set = DefaultAdminSet.create! valid_attributes
        put :update, params: {id: default_admin_set.to_param, default_admin_set: valid_attributes}, session: valid_session
        expect(response).to redirect_to(default_admin_set)
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e. to display the 'edit' template)" do
        default_admin_set = DefaultAdminSet.create! valid_attributes
        put :update, params: {id: default_admin_set.to_param, default_admin_set: invalid_attributes}, session: valid_session
        expect(response).to be_success
      end
    end
  end

  describe "DELETE #destroy" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it "destroys the requested default_admin_set" do
      default_admin_set = DefaultAdminSet.create! valid_attributes
      expect {
        delete :destroy, params: {id: default_admin_set.to_param}, session: valid_session
      }.to change(DefaultAdminSet, :count).by(-1)
    end

    it "redirects to the default_admin_sets list" do
      default_admin_set = DefaultAdminSet.create! valid_attributes
      delete :destroy, params: {id: default_admin_set.to_param}, session: valid_session
      expect(response).to redirect_to(default_admin_sets_url)
    end
  end

end
