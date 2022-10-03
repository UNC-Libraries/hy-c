# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hydra/controller/download_behavior_override.rb')

RSpec.describe Hydra::Controller::DownloadBehavior, type: :controller do
  describe '#show' do

    before do
      class ContentHolder < ActiveFedora::Base
        include Hydra::AccessControls::Permissions
        has_subresource 'thumbnail'
      end
      @user = FactoryBot.create(:user)
      sign_in @user
    end
    let(:obj) do
      ContentHolder.new.tap do |obj|
        obj.add_file("It's a stream", path: 'descMetadata', original_name: 'metadata.xml', mime_type: 'text/plain')
        obj.read_users = [@user.user_key]
        obj.save!
      end
    end

    after do
      obj.destroy
      Object.send(:remove_const, :ContentHolder)
    end

    context 'with downloadable file' do
      # mock MimeTypeService to return true
      it 'will add proper mime type extension if valid' do
        allow(MimeTypeService).to receive(:valid?) { true }
        allow(MimeTypeService).to receive(:label) { 'txt' }
        get :show, params: { id: obj}
        expect(response).to be_successful
        expect(response.headers['Content-Type']).to start_with "text/plain"
        expect(response.headers["Content-Disposition"]).to start_with "inline; filename=\"metadata.xml\""
      end
      it 'will not add mime type extension if not valid' do
        # mock MimeTypeService to return false
        allow(MimeTypeService).to receive(:valid?) { false }
        get :show, params: { id: obj}
        expect(response).to be_successful
        expect(response.headers['Content-Type']).to start_with "text/plain"
        expect(response.headers["Content-Disposition"]).to start_with "inline; filename=\"metadata.xml\""
      end
    end
  end
end
