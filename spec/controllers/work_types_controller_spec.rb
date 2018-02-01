require 'rails_helper'

RSpec.describe WorkTypesController, type: :controller do

  # This should return the minimal set of attributes required to create a valid
  # WorkType. As you add validations to WorkType, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    {work_types: { '1' => {work_type_name: 'an admin set', admin_set_id: 'id123456'},
                   '2' => {work_type_name: 'another admin set', admin_set_id: 'id123456'}}}
  }

  describe "GET #index" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it "returns a success response" do
      work_type = WorkType.create! valid_attributes[:work_types]['1']
      get :index, params: {}
      expect(response).to be_success
    end
  end

  describe "GET #edit" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    it "returns a success response" do
      work_type = WorkType.create! valid_attributes[:work_types]['1']
      get :edit, params: {id: work_type.to_param}
      expect(response).to be_success
    end
  end

  describe "PUT #update" do
    before do
      allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
    end

    context "with valid params" do
      let(:new_attributes) {
        {work_types: { '1' => {work_type_name: 'an admin set', admin_set_id: 'id234567'}}}
      }

      it "updates the requested work_type" do
        work_type = WorkType.create! valid_attributes[:work_types]['1']
        put :update, params: new_attributes
        work_type.reload
        expect(work_type.admin_set_id).to eq 'id234567'
      end

      it "redirects to the index page" do
        work_type = WorkType.create! valid_attributes[:work_types]['1']
        put :update, params: new_attributes
        expect(response).to redirect_to(work_types_path)
      end
    end
  end
end
