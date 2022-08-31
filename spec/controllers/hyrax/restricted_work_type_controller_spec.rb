# frozen_string_literal: true
require 'rails_helper'

RSpec.shared_examples 'a restricted work type' do |model, pluralized_model|
  let(:user) { FactoryBot.create(:user) }

  let(:admin_user) { FactoryBot.create(:admin) }

  let(:admin_set) do
    AdminSet.new(title: ['work admin set'],
                 description: ['some description'],
                 edit_users: [user.user_key])
  end

  describe '#create' do
    let(:actor) { double(create: true) }
    let(:work) { model.create(title: ['new work to be created']) }
    let!(:work_count) { model.all.count }

    context 'with existing admin set as non-admin' do
      before do
        admin_set.save!
        sign_in user
      end

      it 'is not successful' do
        post :create, params: { (model.to_s.downcase.to_sym) => { title: "a new work #{Date.today.to_time.to_i}" } }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
        expect(model.all.count).to eq work_count
      end
    end

    context 'with existing admin set as admin' do
      before do
        admin_set.save!
        sign_in admin_user
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(work) # needs to be called after count is saved for successful examples
      end

      it 'is successful' do
        post :create, params: { (model.to_s.downcase.to_sym) => { title: "a new work #{Date.today.to_time.to_i}" } }
        expect(response).to redirect_to "/concern/#{pluralized_model}/#{work.id}?locale=en"
        expect(flash[:notice]).to eq 'Your files are being processed by the Carolina Digital Repository in the background. The metadata and access controls you specified are being applied. You may need to refresh this page to see these updates.'
        expect(model.all.count).to eq work_count + 1
      end
    end

    context 'without existing admin set as admin' do
      before do
        AdminSet.delete_all
        sign_in admin_user
      end

      it 'is not successful' do
        post :create, params: { (model.to_s.downcase.to_sym) => { title: "a new work #{Date.today.to_time.to_i}" } }
        expect(model.all.count).to eq work_count
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end

    context 'as an unauthenticated user with existing admin set' do
      before do
        admin_set.save!
      end

      it 'is not successful' do
        post :create, params: { (model.to_s.downcase.to_sym) => { title: "a new work #{Date.today.to_time.to_i}" } }
        expect(response).to redirect_to '/users/sign_in?locale=en'
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
        expect(model.all.count).to eq work_count
      end
    end
  end

  describe '#new' do
    context 'with existing admin set as non-admin' do
      before do
        admin_set.save!
        sign_in user
      end

      it 'is not successful' do
        get :new
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end

    context 'with existing admin set as admin' do
      before do
        admin_set.save!
        sign_in admin_user
      end

      it 'is successful' do
        get :new
        expect(response).to be_successful
      end
    end

    context 'without existing admin set' do
      before do
        AdminSet.delete_all
        sign_in user
      end

      it 'is not successful' do
        get :new
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end

    context 'as an unauthenticated user with existing admin set' do
      before do
        admin_set.save!
      end

      it 'is not successful' do
        get :new
        expect(response).to redirect_to '/users/sign_in?locale=en'
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end
  end

  describe '#edit' do
    let(:work) { model.create(title: ['work to be updated']) }

    context 'with existing admin set as non-admin' do
      before do
        admin_set.save!
        sign_in user
      end

      it 'is not successful' do
        get :edit, params: { id: work.id }
        expect(response.status).to eq 401
      end
    end

    context 'with existing admin set as admin' do
      before do
        admin_set.save!
        sign_in admin_user # bypass need for permission template
      end

      it 'is successful' do
        get :edit, params: { id: work.id }
        expect(response).to be_successful
      end
    end

    context 'without existing admin set as admin' do
      before do
        AdminSet.delete_all
        sign_in admin_user # bypass need for permission template
      end

      it 'is not successful' do
        get :edit, params: { id: work.id }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end

    context 'as an unauthenticated user with existing admin set' do
      before do
        admin_set.save!
      end

      it 'is not successful' do
        get :edit, params: { id: work.id }
        expect(response).to redirect_to '/users/sign_in?locale=en'
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end
  end

  describe '#update' do
    let(:actor) { double(update: true) }
    let(:work) { model.create(title: ['work to be updated']) }

    before(:each) do
      allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
      allow(controller).to receive(:curation_concern).and_return(work)
    end

    context 'with existing admin set as non-admin' do
      before do
        admin_set.save!
        sign_in user
      end

      it 'is not successful' do
        patch :update, params: { :id => work.id, (model.to_s.downcase.to_sym) => { abstract: 'an abstract' } }
        expect(response.status).to eq 401
      end
    end

    context 'with existing admin set as admin' do
      before do
        admin_set.save!
        sign_in admin_user # bypass need for permission template
      end

      it 'is successful' do
        patch :update, params: { :id => work.id, (model.to_s.downcase.to_sym) => { abstract: 'an abstract' } }
        expect(response).to redirect_to "/concern/#{pluralized_model}/#{work.id}?locale=en"
        expect(flash[:notice]).to eq "Work \"#{work}\" successfully updated."
      end
    end

    context 'without existing admin set as admin' do
      before do
        AdminSet.delete_all
        sign_in admin_user # bypass need for permission template
      end

      it 'is not successful' do
        patch :update, params: { id: work.id, art_work: { abstract: ['an abstract'] } }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end

    context 'as an unauthenticated user with existing admin set' do
      before do
        admin_set.save!
      end

      it 'is not successful' do
        get :update, params: { :id => work.id, (model.to_s.downcase.to_sym) => { abstract: ['an abstract'] } }
        expect(response).to redirect_to '/users/sign_in?locale=en'
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end
  end

  describe '#destroy' do
    let(:work) { model.create(title: ['work to be deleted']) }
    let(:work_count) { model.all.count }

    context 'as a non-admin' do
      before do
        work
        work_count
        sign_in user
      end

      it 'is not successful' do
        delete :destroy, params: { id: work.id }
        expect(response.status).to eq 401
        expect(model.all.count).to eq work_count
      end
    end

    context 'as an admin' do
      before do
        work
        work_count
        sign_in admin_user
      end

      it 'is successful' do
        delete :destroy, params: { id: work.id }
        expect(response).to redirect_to '/dashboard/my/works?locale=en'
        expect(model.all.count).to eq (work_count - 1)
        expect(flash[:notice]).to eq "Deleted #{work.title.first}"
      end
    end

    context 'as an unauthenticated user' do
      before do
        work
        work_count
      end
      it 'is not successful' do
        delete :destroy, params: { id: work.id }
        expect(response.status).to redirect_to '/users/sign_in?locale=en'
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end
  end
end

RSpec.describe Hyrax::DissertationsController do
  it_behaves_like 'a restricted work type', Dissertation, 'dissertations'
end

RSpec.describe Hyrax::GeneralsController do
  it_behaves_like 'a restricted work type', General, 'generals'
end
