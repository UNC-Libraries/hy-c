# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hyrax/file_sets_controller_override.rb')

RSpec.describe Hyrax::FileSetsController do
  let(:user) { FactoryBot.create(:user) }
  let(:admin_user) { FactoryBot.create(:admin) }
  routes { Rails.application.routes }

  describe '#destroy' do
    let(:file_set) { FactoryBot.create(:file_set, :public, :with_original_file, user: user) }
    let(:work) { FactoryBot.create(:work, title: ['test title'], user: user) }

    before do
      work.ordered_members << file_set
      work.save!
    end

    context 'as a non-admin' do
      before do
        sign_in user
      end

      it 'is not successful' do
        delete :destroy, params: { id: file_set }
        expect(response).to redirect_to '/?locale=en'
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
        expect(response.status).to eq 302
      end
    end

    context 'as an admin' do
      before do
        file_set
        sign_in admin_user
        expect(controller).to receive(:guard_for_workflow_restriction_on!).and_return(true)
      end

      it 'is successful' do
        expect { delete :destroy, params: { id: file_set } }
            .to change { FileSet.exists?(file_set.id) }
            .from(true)
            .to(false)
        expect(response).to redirect_to '/concern/generals/' + work.id + '?locale=en'
        expect(flash[:notice]).to eq 'The file has been deleted.'
        expect(response.status).to eq 302
      end
    end

    context 'as an unauthenticated user' do
      it 'is not successful' do
        delete :destroy, params: { id: file_set }
        expect(response.status).to redirect_to '/users/sign_in'
        expect(flash[:alert]).to eq 'You need to sign in or sign up before continuing.'
      end
    end
  end
end
