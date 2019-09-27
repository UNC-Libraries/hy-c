# Generated via
#  `rails generate hyrax:work Dissertation`
require 'rails_helper'

# test admin set and admin restrictions
RSpec.describe Hyrax::DissertationsController do
  let(:user) do
    User.new(email: "test#{Date.today.to_time.to_i}@example.com", guest: false, uid: "test#{Date.today.to_time.to_i}") { |u| u.save!(validate: false)}
  end

  let(:admin_user) do
    User.find_by_user_key('admin')
  end

  let(:admin_set) do
    AdminSet.new(title: ['dissertation admin set'],
                 description: ['some description'],
                 edit_users: [user.user_key])
  end

  describe '#create' do
    let(:actor) { double(create: true) }

    context 'with existing admin set as non-admin' do
      it 'is not successful' do
        dissertation = Dissertation.create(title: ['new dissertation to be created'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(dissertation)
        admin_set.save!
        sign_in user

        post :create, params: {dissertation: {title: "a new dissertation #{Date.today.to_time.to_i}"}}
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end

    context 'with existing admin set as admin' do
      it 'is successful' do
        dissertation = Dissertation.create(title: ['new dissertation to be created'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(dissertation)
        admin_set.save!
        sign_in admin_user

        post :create, params: {dissertation: {title: "a new dissertation #{Date.today.to_time.to_i}"}}
        expect(response).to redirect_to "/concern/dissertations/#{dissertation.id}?locale=en"
        expect(flash[:notice]).to eq 'Your files are being processed by the Carolina Digital Repository in the background. The metadata and access controls you specified are being applied. You may need to refresh this page to see these updates.'
      end
    end

    context 'without existing admin set as admin' do
      it 'is not successful' do
        AdminSet.delete_all
        sign_in admin_user
        dissertation_count = Dissertation.all.count

        post :create, params: {dissertation: {title: "a new dissertation #{Date.today.to_time.to_i}"}}
        expect(dissertation_count).to eq Dissertation.all.count
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#new' do
    context 'with existing admin set as non-admin' do
      it 'is not successful' do
        admin_set.save!
        sign_in user

        get :new
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end

    context 'with existing admin set as admin' do
      it 'is successful' do
        admin_set.save!
        sign_in admin_user

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
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end
  end

  describe '#edit' do
    context 'with existing admin set as non-admin' do
      it 'is not successful' do
        admin_set.save!
        dissertation = Dissertation.create(title: ['work to be updated'])
        sign_in user # bypass need for permission template

        get :edit, params: { id: dissertation.id }
        expect(response.status).to eq 401
      end
    end

    context 'with existing admin set as admin' do
      it 'is successful' do
        admin_set.save!
        dissertation = Dissertation.create(title: ['work to be updated'])
        sign_in admin_user # bypass need for permission template

        get :edit, params: { id: dissertation.id }
        expect(response).to be_successful
      end
    end

    context 'without existing admin set as admin' do
      it 'is not successful' do
        dissertation = Dissertation.create(title: ['work to be updated'])
        AdminSet.delete_all
        sign_in admin_user # bypass need for permission template

        get :edit, params: { id: dissertation.id }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#update' do
    let(:actor) { double(update: true) }

    context 'with existing admin set as non-admin' do
      it 'is not successful' do
        admin_set.save!
        dissertation = Dissertation.create(title: ['work to be updated'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(dissertation)
        sign_in user

        patch :update, params: { id: dissertation.id, dissertation: {abstract: 'an abstract'} }
        expect(response.status).to eq 401
      end
    end

    context 'with existing admin set as admin' do
      it 'is successful' do
        admin_set.save!
        dissertation = Dissertation.create(title: ['work to be updated'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(dissertation)
        sign_in admin_user # bypass need for permission template

        patch :update, params: { id: dissertation.id, dissertation: {abstract: 'an abstract'} }
        expect(response).to redirect_to "/concern/dissertations/#{dissertation.id}?locale=en"
        expect(flash[:notice]).to eq "Work \"#{dissertation}\" successfully updated."
      end
    end

    context 'without existing admin set as admin' do
      it 'is not successful' do
        dissertation = Dissertation.create(title: ['work to be updated'])
        AdminSet.delete_all
        sign_in admin_user # bypass need for permission template

        patch :update, params: { id: dissertation.id, art_work: {abstract: ['an abstract']} }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#destroy' do
    context 'as a non-admin' do
      it 'is not successful' do
        dissertation = Dissertation.create(title: ['work to be deleted'])
        dissertation_count = Dissertation.all.count
        sign_in user

        delete :destroy, params: { id: dissertation.id }
        expect(response.status).to eq 401
        expect(Dissertation.all.count).to eq dissertation_count
      end
    end

    context 'as an admin' do
      it 'is successful' do
        dissertation = Dissertation.create(title: ['work to be deleted'])
        dissertation_count = Dissertation.all.count
        sign_in admin_user

        delete :destroy, params: { id: dissertation.id }
        expect(response).to redirect_to '/dashboard/my/works?locale=en'
        expect(Dissertation.all.count).to eq (dissertation_count-1)
        expect(flash[:notice]).to eq "Deleted #{dissertation.title.first}"
      end
    end
  end
end
