# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'

# test admin set and admin restrictions
RSpec.describe Hyrax::MastersPapersController do
  let(:user) do
    User.new(email: "test#{Date.today.to_time.to_i}@example.com", guest: false, uid: "test#{Date.today.to_time.to_i}") { |u| u.save!(validate: false)}
  end

  let(:admin_user) do
    User.find_by_user_key('admin')
  end

  let(:admin_set) do
    AdminSet.new(title: ['masters_paper admin set'],
                 description: ['some description'],
                 edit_users: [user.user_key])
  end

  describe '#create' do
    let(:actor) { double(create: true) }

    context 'with existing admin set' do
      it 'is successful' do
        masters_paper = MastersPaper.create(title: ['new masters_paper to be created'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(masters_paper)
        admin_set.save!
        sign_in user

        post :create, params: {masters_paper: {title: "a new masters_paper #{Date.today.to_time.to_i}"}}
        expect(response).to redirect_to "/concern/masters_papers/#{masters_paper.id}?locale=en"
        expect(flash[:notice]).to eq 'Your files are being processed by the Carolina Digital Repository in the background. The metadata and access controls you specified are being applied. You may need to refresh this page to see these updates.'
      end
    end

    context 'without existing admin set' do
      it 'is not successful' do
        AdminSet.delete_all
        sign_in user
        masters_paper_count = MastersPaper.all.count

        post :create, params: {masters_paper: {title: "a new masters_paper #{Date.today.to_time.to_i}"}}
        expect(masters_paper_count).to eq MastersPaper.all.count
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
        masters_paper = MastersPaper.create(title: ['work to be updated'])
        sign_in admin_user # bypass need for permission template

        get :edit, params: { id: masters_paper.id }
        expect(response).to be_successful
      end
    end

    context 'without existing admin set' do
      it 'is not successful' do
        masters_paper = MastersPaper.create(title: ['work to be updated'])
        AdminSet.delete_all
        sign_in admin_user # bypass need for permission template

        get :edit, params: { id: masters_paper.id }
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
        masters_paper = MastersPaper.create(title: ['work to be updated'])
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(masters_paper)
        allow(controller).to receive(:authorize!).with(:update, masters_paper).and_return(true) # give non-admin permission to update
        sign_in user

        patch :update, params: { id: masters_paper.id, masters_paper: {abstract: 'an abstract'} }
        expect(response).to redirect_to "/concern/masters_papers/#{masters_paper.id}?locale=en"
        expect(flash[:notice]).to eq "Work \"#{masters_paper}\" successfully updated."
      end
    end

    context 'without existing admin set' do
      it 'is not successful' do
        masters_paper = MastersPaper.create(title: ['work to be updated'])
        AdminSet.delete_all
        allow(controller).to receive(:authorize!).with(:update, masters_paper).and_return(true) # give non-admin permission to update
        sign_in user

        patch :update, params: { id: masters_paper.id, art_work: {abstract: ['an abstract']} }
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
      end
    end
  end

  describe '#destroy' do
    context 'as a non-admin' do
      it 'is not successful' do
        masters_paper = MastersPaper.create(title: ['work to be deleted'])
        masters_paper_count = MastersPaper.all.count
        sign_in user

        delete :destroy, params: { id: masters_paper.id }
        expect(response.status).to eq 401
        expect(MastersPaper.all.count).to eq masters_paper_count
      end
    end

    context 'as an admin' do
      it 'is successful' do
        masters_paper = MastersPaper.create(title: ['work to be deleted'])
        masters_paper_count = MastersPaper.all.count
        sign_in admin_user

        delete :destroy, params: { id: masters_paper.id }
        expect(response).to redirect_to '/dashboard/my/works?locale=en'
        expect(MastersPaper.all.count).to eq (masters_paper_count-1)
        expect(flash[:notice]).to eq "Deleted #{masters_paper.title.first}"
      end
    end
  end
end
