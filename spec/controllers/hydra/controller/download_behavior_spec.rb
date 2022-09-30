# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/concerns/hydra/controller/download_behavior_override.rb')

RSpec.describe Hydra::Controller::DownloadBehavior do
  describe '#file_name' do
    let(:user) { FactoryBot.create(:user) }
    before { sign_in user }

    context 'with valid mime_type' do
      # mock MimeTypeService to return true
      allow(Hyrax::MimeTypeService).to receive(:valid?) { true }
      allow(Hyrax::MimeTypeService).to receive(:label) { 'mp3' }
      get :show, params: { filename: 'test_filename.mp4'}
      expect(file_name).to eq('test_filename.mp4.mp3')
    end
    context 'without valid mime_type' do
      # mock MimeTypeService to return false
      allow(Hyrax::MimeTypeService).to receive(:valid?) { false }
      get :show, params: { filename: 'test_filename.mp4'}
      expect(file_name).to eq('test_filename.mp4')
    end
  end
end
