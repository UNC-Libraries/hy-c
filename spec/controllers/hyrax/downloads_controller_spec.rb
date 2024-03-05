# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hydra/controller/download_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/hyrax/downloads_controller_override.rb')

RSpec.describe Hyrax::DownloadsController, type: :controller do
  routes { Hyrax::Engine.routes }
  let(:base_analytics_url) { 'https://www.google-analytics.com/mp/collect?api_secret=supersecret&measurement_id=analytics_id' }

  let(:stub_ga) do
    stub_request(:post, base_analytics_url).to_return(status: 200, body: '', headers: {})
  end

  around do |example|
    cached_secret = ENV['ANALYTICS_API_SECRET']
    ENV['ANALYTICS_API_SECRET'] = 'supersecret'
    example.run
    ENV['ANALYTICS_API_SECRET'] = cached_secret
  end

  before do
    ActiveFedora::Cleaner.clean!
    allow(stub_ga)
    allow(Hyrax::Analytics.config).to receive(:analytics_id).and_return('analytics_id')
    allow(SecureRandom).to receive(:uuid).and_return('555')
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  # app/controllers/concerns/hyrax/download_analytics_behavior.rb:8
  describe '#track_download' do
    WebMock.after_request do |request_signature, response|
      Rails.logger.debug("Request #{request_signature} was made and #{response} was returned")
    end

    it 'has the method for tracking analytics for download' do
      allow(controller.request).to receive(:referrer).and_return('http://example.com')
      expect(controller).to respond_to(:track_download)
      expect(controller.track_download).to eq 200
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
        request.env['HTTP_REFERER'] = 'http://example.com'
        stub = stub_request(:post, base_analytics_url)
               .with(body: { 'client_id': '555', "events": [{
                    "name": 'DownloadIR',
                    "params": {
                      "category": 'Unknown',
                      "label": file_set.id,
                      "host_name": 'test.host',
                      "medium": 'referral',
                      "page_referrer": 'http://example.com',
                      "page_location": "http://test.host/downloads/#{file_set.id}"
                    }
                  }]
                }.to_json)
               .to_return(status: 200, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
      end

      it 'sets the medium to direct when there is no referrer' do
        allow(controller).to receive(:cookies) { { _ga: 'ga.1.2.3'} }
        request.env['HTTP_REFERER'] = nil
        stub = stub_request(:post, base_analytics_url)
               .with(body: { 'client_id': '2.3', "events": [{
                    "name": 'DownloadIR',
                    "params": {
                      "category": 'Unknown',
                      "label": file_set.id,
                      "host_name": 'test.host',
                      "medium": 'direct',
                      "page_referrer": nil,
                      "page_location": "http://test.host/downloads/#{file_set.id}"
                    }
                  }]
                }.to_json)
               .to_return(status: 200, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
      end

      it 'logs an error for a 400 response' do
        allow(Rails.logger).to receive(:error)
        request.env['HTTP_REFERER'] = 'http://example.com'
        stub = stub_request(:post, base_analytics_url)
               .to_return(status: 400, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
        expect(Rails.logger).to have_received(:error).exactly(1).times
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

      it 'will add correct extension when mimetype has a different extension' do
        allow(MimeTypeService).to receive(:label) { 'txt' }

        get :show, params: { id: file_set}
        expect(response).to be_successful
        expect(response.headers['Content-Disposition']).to include 'filename="image.png.txt"'
      end

      it 'will not add extension when no extension for mimetype' do
        allow(MimeTypeService).to receive(:label) { nil }

        get :show, params: { id: file_set}
        expect(response).to be_successful
        expect(response.headers['Content-Disposition']).to include 'filename="image.png"'
      end

      it 'will not add mime type extension when vocabulary mimetype extension is the same as original extension' do
        allow(MimeTypeService).to receive(:label) { 'png' }

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

      it 'downloads whole file when byte Range not specified' do
        request.headers['HTTP_RANGE'] = 'bytes='
        get :show, params: { id: file_set}
        expect(response.status).to eq 206
        expect(response.headers['Content-Disposition']).to include 'filename="image.png"'
        expect(response.headers['Content-Range']).to include 'bytes 0-19101/19102'
      end
    end
    context 'with file set for download without file extension' do
      let(:file_set) do
        FactoryBot.create(:file_with_work, user: @user, content: File.open("#{fixture_path}/files/no_extension"))
      end

      before do
        allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
      end

      it 'will add extension added when vocab provides one' do
        allow(MimeTypeService).to receive(:label) { 'jpg' }

        get :show, params: { id: file_set}
        expect(response).to be_successful
        expect(response.headers['Content-Disposition']).to include 'filename="no_extension.jpg"'
      end

      it 'will not add extension added when vocab does not have one for mimetype' do
        allow(MimeTypeService).to receive(:label) { nil }

        get :show, params: { id: file_set}
        expect(response).to be_successful
        expect(response.headers['Content-Disposition']).to include 'filename="no_extension"'
      end
    end
  end
end
