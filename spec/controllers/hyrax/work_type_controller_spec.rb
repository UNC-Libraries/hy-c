require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.shared_examples 'a work type' do |model, pluralized_model|
  let(:user) { FactoryBot.create(:user) }

  let(:admin_user) { FactoryBot.create(:admin) }

  let(:admin_set) do
    AdminSet.new(title: ['an admin set'],
                 description: ['some description'],
                 edit_users: [user.user_key])
  end

  before(:all) do
    ActiveFedora::Cleaner.clean!
  end

  describe '#create' do
    let(:actor) { double(create: true) }
    let(:work) { model.create(title: ['new work to be created']) }
    let!(:work_count) { model.all.count }

    context 'with existing admin set' do
      before do
        sign_in user
        admin_set.save!
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

    context 'without existing admin set' do
      before do
        sign_in user
        AdminSet.delete_all
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
    context 'with existing admin set' do
      before do
        admin_set.save!
        sign_in user
      end

      it 'is successful' do
        get :new
        expect(response).to be_success
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
        expect(flash[:alert]).to eq 'No Admin Sets have been created.'
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

    context 'with existing admin set' do
      before do
        admin_set.save!
        sign_in admin_user # bypass need for permission template
      end

      it 'is successful' do
        get :edit, params: { id: work.id }
        expect(response).to be_success
      end
    end

    context 'without existing admin set' do
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

    context 'with existing admin set' do
      before do
        admin_set.save!
        sign_in user
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(work)
        allow(controller).to receive(:authorize!).with(:update, work).and_return(true) # give non-admin permission to update
      end

      it 'is successful' do
        patch :update, params: { :id => work.id, (model.to_s.downcase.to_sym) => { abstract: 'an abstract' } }
        expect(response).to redirect_to "/concern/#{pluralized_model}/#{work.id}?locale=en"
        expect(flash[:notice]).to eq "Work \"#{work}\" successfully updated."
      end
    end

    context 'without existing admin set' do
      before do
        AdminSet.delete_all
        sign_in user
        allow(Hyrax::CurationConcern).to receive(:actor).and_return(actor)
        allow(controller).to receive(:curation_concern).and_return(work)
        allow(controller).to receive(:authorize!).with(:update, work).and_return(true) # give non-admin permission to update
      end

      it 'is not successful' do
        patch :update, params: { :id => work.id, (model.to_s.downcase.to_sym) => { abstract: ['an abstract'] } }
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
    let(:work) { model.create(title: ['new work to be destroyed']) }
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
        work_count # needs to be set before work is deleted
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
      it 'is not successful' do
        delete :destroy, params: { id: work.id }
        expect(response.status).to redirect_to '/users/sign_in?locale=en'
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end
  end
end

RSpec.describe Hyrax::ArtworksController do
  it_behaves_like 'a work type', Artwork, 'artworks'
end

RSpec.describe Hyrax::ArticlesController do
  it_behaves_like 'a work type', Article, 'articles'
end

RSpec.describe Hyrax::DataSetsController do
  it_behaves_like 'a work type', DataSet, 'data_sets'
end

RSpec.describe Hyrax::HonorsThesesController do
  it_behaves_like 'a work type', HonorsThesis, 'honors_theses'
end

RSpec.describe Hyrax::JournalsController do
  it_behaves_like 'a work type', Journal, 'journals'
end

RSpec.describe Hyrax::MastersPapersController do
  it_behaves_like 'a work type', MastersPaper, 'masters_papers'
end

RSpec.describe Hyrax::MultimedsController do
  it_behaves_like 'a work type', Multimed, 'multimeds'
end

RSpec.describe Hyrax::ScholarlyWorksController do
  it_behaves_like 'a work type', ScholarlyWork, 'scholarly_works'
end
