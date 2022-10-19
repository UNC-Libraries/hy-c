# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hydra/controller/download_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/hyrax/downloads_controller_override.rb')

RSpec.describe Hyrax::DownloadsController, type: :controller do
  routes { Hyrax::Engine.routes }

  let(:stub_ga) do
    stub_request(:post, 'http://www.google-analytics.com/collect').to_return(status: 200, body: '', headers: {})
  end

  before do
    allow(stub_ga)
  end

  # app/controllers/concerns/hyrax/download_analytics_behavior.rb:8
  describe '#track_download' do
    WebMock.after_request do |request_signature, response|
      Rails.logger.debug("Request #{request_signature} was made and #{response} was returned")
    end

    it 'has the method for tracking analytics for download' do
      allow(Hyrax.config).to receive(:google_analytics_id).and_return('blah')
      allow(controller.request).to receive(:referrer).and_return('http://example.com')
      expect(controller).to respond_to(:track_download)
      expect(controller.track_download).to be_a_kind_of Net::HTTPOK
      expect(stub_ga).to have_been_requested.times(1) # must be after the method call that creates request
    end

    context 'with a created work' do
      let(:user) { FactoryBot.create(:user) }
      before { sign_in user }
      let(:file_set) do
        FactoryBot.create(:file_with_work, user: user, content: File.open("#{fixture_path}/files/image.png"))
      end
      let(:default_image) { ActionController::Base.helpers.image_path 'default.png' }

      it 'can use a fake request' do
        allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
        allow(SecureRandom).to receive(:uuid).and_return('555')
        allow(Hyrax.config).to receive(:google_analytics_id).and_return('blah')
        request.env['HTTP_REFERER'] = 'http://example.com'
        stub = stub_request(:post, 'http://www.google-analytics.com/collect')
               .with(body: { 'cid' => '555', 'cm' => 'referral', 'dr' => 'http://example.com', 'ds' => 'server-side', 'ea' => 'DownloadIR',
                             'ec' => 'Unknown', 'el' => file_set.id, 't' => 'event', 'tid' => 'blah',
                             'ua' => 'Rails Testing', 'uip' => '0.0.0.0', 'v' => '1' })
               .to_return(status: 200, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
      end

      it 'sets the medium to direct when there is no referrer' do
        allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
        allow(SecureRandom).to receive(:uuid).and_return('555')
        allow(Hyrax.config).to receive(:google_analytics_id).and_return('blah')
        request.env['HTTP_REFERER'] = nil
        stub = stub_request(:post, 'http://www.google-analytics.com/collect')
               .with(body: { 'cid' => '555', 'cm' => 'direct', 'ds' => 'server-side', 'ea' => 'DownloadIR',
                             'ec' => 'Unknown', 'el' => file_set.id, 't' => 'event', 'tid' => 'blah',
                             'ua' => 'Rails Testing', 'uip' => '0.0.0.0', 'v' => '1' })
               .to_return(status: 200, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
      end
    end
  end

  # app/controllers/hyrax/downloads_controller.rb:6
  describe '#set_record_admin_set' do
    let(:solr_response) { { response: { docs: [{ admin_set_tesim: ['admin set for download controller'] }] } }.to_json }
    let(:empty_solr_response) { { response: { docs: [] } }.to_json }

    context 'with a solr response' do
      before do
        stub_request(:get, /solr/).to_return(body: solr_response)
      end

      it 'finds admin set for file set' do
        expect(controller.set_record_admin_set).to eq('admin set for download controller')
      end
    end

    context 'with an empty solr response' do
      before do
        stub_request(:get, /solr/).to_return(body: empty_solr_response)
      end

      it 'does not find admin set for file set' do
        expect(controller.set_record_admin_set).to eq('Unknown')
      end
    end
  end

  describe '#download_file' do
    before do
      @user = FactoryBot.create(:user)
      sign_in @user
    end

    context 'with file set for download' do
      let(:file_set) do
        FactoryBot.create(:file_with_work, user: @user, content: File.open("#{fixture_path}/files/image.png"))
      end

      before do
        allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
      end

      it 'will add proper mime type extension if valid' do
        allow(MimeTypeService).to receive(:valid?) { true }
        allow(MimeTypeService).to receive(:label) { 'txt' }

        get :show, params: { id: file_set}
        expect(response).to be_successful
        expect(response.headers['Content-Disposition']).to include 'filename="image.png.txt"'
      end

      it 'will not add mime type extension if not valid' do
        allow(MimeTypeService).to receive(:valid?) { false }

        get :show, params: { id: file_set}
        expect(response).to be_successful
        expect(response.headers['Content-Disposition']).to include 'filename="image.png"'
      end

      context 'when permission denied' do
        before do
          allow(subject).to receive(:authorize!).and_raise(CanCan::AccessDenied)
        end

        it 'gets 401 response' do
          get :show, params: { id: file_set}
          expect(response).to be_unauthorized
        end
      end

      context 'when record not found' do
        before do
          allow(subject).to receive(:authorize!).and_raise(Blacklight::Exceptions::RecordNotFound)
        end

        it 'gets 404 response' do
          get :show, params: { id: file_set}
          expect(response).to be_not_found
        end
      end
    end
  end
end
