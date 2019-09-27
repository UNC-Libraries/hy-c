# Generated via
#  `rails generate hyrax:work ScholarlyWork`
require 'rails_helper'

# test admin set and admin restrictions
RSpec.describe Hyrax::ScholarlyWorksController do
  let(:user) do
    User.new(email: "test#{Date.today.to_time.to_i}@example.com", guest: false, uid: "test#{Date.today.to_time.to_i}") { |u| u.save!(validate: false)}
  end

  let(:admin_user) do
    User.find_by_user_key('admin')
  end

  let(:admin_set) do
    AdminSet.new(title: ['scholarly_work admin set'],
                 description: ['some description'],
                 edit_users: [user.user_key])
  end

  describe '#create' do
    let(:actor) { double(create: true) }

    context 'with existing admin set' do
      it 'is successful' do
        scholarly_work = ScholarlyWork.create(title: ['new scholarly_work to be created'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(scholarly_work)
        admin_set.save!
        sign_in user

        post :create, params: {scholarly_work: {title: "a new scholarly_work #{Date.today.to_time.to_i}"}}
        expect(response).to redirect_to "/concern/scholarly_works/#{scholarly_work.id}?locale=en"
        expect(flash[:notice]).to eq 'Your files are being processed by the Carolina Digital Repository in the background. The metadata and access controls you specified are being applied. You may need to refresh this page to see these updates.'
      end
    end

    context 'without existing admin set' do
      it 'is not successful' do
        AdminSet.delete_all
        sign_in user
        scholarly_work_count = ScholarlyWork.all.count

        post :create, params: {scholarly_work: {title: "a new scholarly_work #{Date.today.to_time.to_i}"}}
        expect(scholarly_work_count).to eq ScholarlyWork.all.count
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#new' do
    context 'with existing admin set' do
      it 'is successful' do
        admin_set.save!
        sign_in user

        get :new
        expect(response).to be_successful
      end
    end

    context 'without existing admin set' do
      it 'is not successful' do
        AdminSet.delete_all
        sign_in user

        get :new
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#edit' do
    context 'with existing admin set' do
      it 'is successful' do
        admin_set.save!
        scholarly_work = ScholarlyWork.create(title: ['work to be updated'])
        sign_in admin_user # bypass need for permission template

        get :edit, params: { id: scholarly_work.id }
        expect(response).to be_successful
      end
    end

    context 'without existing admin set' do
      it 'is not successful' do
        scholarly_work = ScholarlyWork.create(title: ['work to be updated'])
        AdminSet.delete_all
        sign_in admin_user # bypass need for permission template

        get :edit, params: { id: scholarly_work.id }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#update' do
    let(:actor) { double(update: true) }

    context 'with existing admin set' do
      it 'is successful' do
        admin_set.save!
        scholarly_work = ScholarlyWork.create(title: ['work to be updated'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(scholarly_work)
        allow(controller).to receive(:authorize!).with(:update, scholarly_work).and_return(true) # give non-admin permission to update
        sign_in user

        patch :update, params: { id: scholarly_work.id, scholarly_work: {abstract: 'an abstract'} }
        expect(response).to redirect_to "/concern/scholarly_works/#{scholarly_work.id}?locale=en"
        expect(flash[:notice]).to eq "Work \"#{scholarly_work}\" successfully updated."
      end
    end

    context 'without existing admin set' do
      it 'is not successful' do
        scholarly_work = ScholarlyWork.create(title: ['work to be updated'])
        AdminSet.delete_all
        allow(controller).to receive(:authorize!).with(:update, scholarly_work).and_return(true) # give non-admin permission to update
        sign_in user

        patch :update, params: { id: scholarly_work.id, art_work: {abstract: ['an abstract']} }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#destroy' do
    context 'as a non-admin' do
      it 'is not successful' do
        scholarly_work = ScholarlyWork.create(title: ['work to be deleted'])
        scholarly_work_count = ScholarlyWork.all.count
        sign_in user

        delete :destroy, params: { id: scholarly_work.id }
        expect(response.status).to eq 401
        expect(ScholarlyWork.all.count).to eq scholarly_work_count
      end
    end

    context 'as an admin' do
      it 'is successful' do
        scholarly_work = ScholarlyWork.create(title: ['work to be deleted'])
        scholarly_work_count = ScholarlyWork.all.count
        sign_in admin_user

        delete :destroy, params: { id: scholarly_work.id }
        expect(response).to redirect_to '/dashboard/my/works?locale=en'
        expect(ScholarlyWork.all.count).to eq (scholarly_work_count-1)
        expect(flash[:notice]).to eq "Deleted #{scholarly_work.title.first}"
      end
    end
  end
end
