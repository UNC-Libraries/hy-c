require 'rails_helper'

RSpec.describe DefaultAdminSetsController, type: :controller do

  # This should return the minimal set of attributes required to create a valid
  # DefaultAdminSet. As you add validations to DefaultAdminSet, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    {work_type_name: 'a work type', admin_set_id: 'id123456'}
  }

  let(:invalid_attributes) {
    {new_param: 'hi'}
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # DefaultAdminSetsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET #index" do
    context 'as an admin' do
      before do
        allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
        DefaultAdminSet.create! valid_attributes
      end

      it "returns a success response" do
        get :index, params: {}, session: valid_session
        expect(response).to be_success
      end
    end

    context 'as a non-admin' do
      before do
        DefaultAdminSet.create! valid_attributes
      end

      it "returns an unauthorized response" do
        get :index, params: {}, session: valid_session
        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe "GET #new" do
    context 'as an admin' do
      before do
        allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
      end

      it "returns a success response" do
        get :new, params: {}, session: valid_session
        expect(response).to be_success
      end
    end

    context 'as a non-admin' do
      it "returns an unauthorized response" do
        get :new, params: {}, session: valid_session
        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe "GET #edit" do
    let(:default_admin_set) { DefaultAdminSet.create! valid_attributes }

    context 'as an admin' do
      before do
        allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
      end

      it "returns a success response" do
        get :edit, params: {id: default_admin_set.to_param}, session: valid_session
        expect(response).to be_success
      end
    end

    context 'as a non-admin' do
      it "returns an unauthorized response" do
        get :edit, params: {id: default_admin_set.to_param}, session: valid_session
        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe "POST #create" do
    context 'as an admin' do
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
          expect(response).to redirect_to default_admin_sets_path
        end
      end

      context "with invalid params" do
        it "returns a success response (i.e. to display the 'new' template)" do
          post :create, params: {default_admin_set: invalid_attributes}, session: valid_session
          expect(response).to be_success
        end
      end
    end

    context 'as a non-admin' do
      context "with valid params" do
        it "does not create a new DefaultAdminSet" do
          expect {
            post :create, params: {default_admin_set: valid_attributes}, session: valid_session
          }.to change(DefaultAdminSet, :count).by(0)
        end

        it "redirects to the login page" do
          post :create, params: {default_admin_set: valid_attributes}, session: valid_session
          expect(response).to redirect_to new_user_session_path
        end
      end

      context "with invalid params" do
        it "redirects to the login page" do
          post :create, params: {default_admin_set: invalid_attributes}, session: valid_session
          expect(response).to redirect_to new_user_session_path
        end
      end
    end
  end

  describe "PUT #update" do
    context 'as an admin' do
      before do
        allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
      end

      context "with valid params" do
        let(:new_attributes) {
          {work_type_name: 'another work type', admin_set_id: 'id98237498'}
        }
        let(:default_admin_set) { DefaultAdminSet.create! valid_attributes }

        it "updates the requested default_admin_set" do
          expect(default_admin_set.work_type_name).to eq 'a work type'
          expect(default_admin_set.admin_set_id).to eq 'id123456'
          put :update, params: {id: default_admin_set.to_param, default_admin_set: new_attributes},
              session: valid_session
          default_admin_set.reload
          expect(default_admin_set.work_type_name).to eq 'another work type'
          expect(default_admin_set.admin_set_id).to eq 'id98237498'
        end

        it "redirects to the default_admin_set" do
          put :update, params: {id: default_admin_set.to_param, default_admin_set: valid_attributes},
              session: valid_session
          expect(response).to redirect_to default_admin_sets_path
          expect(flash[:notice]).to eq 'Admin set worktype was successfully updated.'
        end
      end

      context "with invalid params" do
        let(:default_admin_set) { DefaultAdminSet.create! valid_attributes }

        it "returns a redirect response" do
          put :update, params: {id: default_admin_set.to_param, default_admin_set: invalid_attributes},
              session: valid_session
          expect(response).to redirect_to default_admin_sets_path
        end
      end
    end

    context 'as a non-admin' do
      context "with valid params" do
        let(:new_attributes) {
          {work_type_name: 'another work type', admin_set_id: 'id98237498'}
        }
        let(:default_admin_set) { DefaultAdminSet.create! valid_attributes }

        it "does not update the requested default_admin_set" do
          expect(default_admin_set.work_type_name).to eq 'a work type'
          expect(default_admin_set.admin_set_id).to eq 'id123456'
          put :update, params: {id: default_admin_set.to_param, default_admin_set: new_attributes},
              session: valid_session
          default_admin_set.reload
          expect(default_admin_set.work_type_name).to eq 'a work type'
          expect(default_admin_set.admin_set_id).to eq 'id123456'
        end

        it "redirects to the login page" do
          put :update, params: {id: default_admin_set.to_param, default_admin_set: valid_attributes},
              session: valid_session
          expect(response).to redirect_to new_user_session_path
        end
      end

      context "with invalid params" do
        let(:default_admin_set) { DefaultAdminSet.create! valid_attributes }

        it "redirects to the login page" do
          put :update, params: {id: default_admin_set.to_param, default_admin_set: invalid_attributes},
              session: valid_session
          expect(response).to redirect_to new_user_session_path
        end
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:default_admin_set) { DefaultAdminSet.create! valid_attributes }

    context 'as an admin' do
      before do
        allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
      end

      it "destroys the requested default_admin_set" do
        expect {
          delete :destroy, params: {id: default_admin_set.to_param}, session: valid_session
        }.to change(DefaultAdminSet, :count).by(-1)
      end

      it "redirects to the default_admin_sets list" do
        delete :destroy, params: {id: default_admin_set.to_param}, session: valid_session
        expect(response).to redirect_to default_admin_sets_url
      end
    end

    context 'as a non-admin' do
      it "does not destroy the requested default_admin_set" do
        expect {
          delete :destroy, params: {id: default_admin_set.to_param}, session: valid_session
        }.to change(DefaultAdminSet, :count).by(0)
      end

      it "redirects to the login page" do
        delete :destroy, params: {id: default_admin_set.to_param}, session: valid_session
        expect(response).to redirect_to new_user_session_path
      end
    end
  end
end
