# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hydra/controller/download_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/hyrax/downloads_controller_override.rb')

RSpec.describe Hyrax::DownloadsController, type: :controller do
  routes { Hyrax::Engine.routes }
  let(:user) { FactoryBot.create(:user, uid: 'downloads_controller_test_user') }
  let(:spec_base_analytics_url) { 'https://analytics-qa.lib.unc.edu' }
  let(:spec_site_id) { '5' }
  let(:spec_auth_token) { 'testtoken' }
  let(:stub_matomo) do
    stub_request(:get, "#{spec_base_analytics_url}/matomo.php").with(query: hash_including({'token_auth' => 'testtoken',
                                                                       'idsite' => '5'}))
    .to_return(status: 200, body: '', headers: {})
  end
  let(:example_admin_set_id) { 'h128zk07m' }
  let(:example_work_id) { '1z40m031g' }
  let(:mock_admin_set) { [{
    'has_model_ssim' => ['AdminSet'],
    'id' => 'h128zk07m',
    'title_tesim' => ['Open_Access_Articles_and_Book_Chapters']}
  ]
  }
  let(:mock_record) { [{
    'has_model_ssim' => ['Article'],
    'id' =>  '1z40m031g',
    'title_tesim' => ['Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response'],
    'admin_set_tesim' => ['Open_Access_Articles_and_Book_Chapters']}
  ]
  }
  let(:file_set) do
    FactoryBot.create(:file_with_work, user: user, content: File.open("#{fixture_path}/files/image.png"))
  end

  around do |example|
    # Set the environment variables for the test
    @auth_token = ENV['MATOMO_AUTH_TOKEN']
    @site_id = ENV['MATOMO_SITE_ID']
    @matomo_base_url = ENV['MATOMO_BASE_URL']
    ENV['MATOMO_AUTH_TOKEN'] = spec_auth_token
    ENV['MATOMO_SITE_ID'] = spec_site_id
    ENV['MATOMO_BASE_URL'] = spec_base_analytics_url
    example.run
    # Reset the environment variables
    ENV['MATOMO_AUTH_TOKEN'] = @auth_token
    ENV['MATOMO_SITE_ID'] = @site_id
    ENV['MATOMO_BASE_URL'] = @matomo_base_url
  end

  before do
    ActiveFedora::Cleaner.clean!
    allow(stub_matomo)
    @user = user
    sign_in @user
    allow(controller).to receive(:fetch_record).and_return(mock_record)
    allow(controller).to receive(:fetch_admin_set).and_return(mock_admin_set)
    allow(Hyrax::Analytics.config).to receive(:site_id).and_return(spec_site_id)
    allow(SecureRandom).to receive(:uuid).and_return('555')
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  describe '#track_download' do
    WebMock.after_request do |request_signature, response|
      Rails.logger.debug("Request #{request_signature} was made and #{response} was returned")
    end

    it 'has the method for tracking analytics for download' do
      allow(ActiveFedora::SolrService).to receive(:get).and_return(
        {
        'response' => {
          'docs' => [
            { 'id' => 'id',
              'file_set_ids_ssim' => 'file-id',
              'title_tesim' => ['Test Title']}
          ]
        }
      }
      )
      allow(controller.request).to receive(:referrer).and_return('http://example.com')
      expect(controller).to respond_to(:track_download)
      expect(controller.track_download).to eq 200
      expect(stub_matomo).to have_been_requested.times(1) # must be after the method call that creates request
    end

    context 'with a created work' do
      let(:default_image) { ActionController::Base.helpers.image_path 'default.png' }

      it 'sends a download event to analytics tracking platform upon successful download' do
        request.env['HTTP_REFERER'] = 'http://example.com'
        stub = stub_request(:get, "#{spec_base_analytics_url}/matomo.php")
          .with(query: hash_including({'e_a' => 'DownloadIR',
                                      'e_c' => 'Unknown',
                                      'e_n' => file_set.id,
                                      'e_v' => 'referral',
                                      'urlref' => 'http://example.com',
                                      'url' => "http://test.host/downloads/#{file_set.id}"
                                      }))
            .to_return(status: 200, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
      end

      it 'records the download event in the database' do
        request.env['HTTP_REFERER'] = 'http://example.com'

        expect {
          get :show, params: { id: file_set.id }
        }.to change { HycDownloadStat.count }.by(1)

        stat = HycDownloadStat.last
        expect(stat.fileset_id).to eq(file_set.id)
        expect(stat.work_id).to eq(example_work_id)
        expect(stat.admin_set_id).to eq(example_admin_set_id)
        expect(stat.date).to eq(Date.today.beginning_of_month)
        expect(stat.download_count).to eq(1)
      end

      it 'updates the download count if the record already exists' do
        existing_download_count = 5
        request.env['HTTP_REFERER'] = 'http://example.com'

        existing_stat = HycDownloadStat.create!(
          fileset_id: file_set.id,
          work_id: example_work_id,
          admin_set_id: example_admin_set_id,
          work_type: 'Article',
          date: Date.today.beginning_of_month,
          download_count: existing_download_count
        )

        expect {
          get :show, params: { id: file_set.id }
        }.not_to change { HycDownloadStat.count }

        stat = HycDownloadStat.last
        expect(stat.fileset_id).to eq(file_set.id)
        expect(stat.work_id).to eq(example_work_id)
        expect(stat.admin_set_id).to eq(example_admin_set_id)
        expect(stat.date).to eq(Date.today.beginning_of_month)
        expect(stat.download_count).to eq(existing_download_count + 1)
      end

      it 'does not track downloads for well known bot user agents' do
       # Testing with two well known user agents to account for potential changes in bot filtering due to updates in the Browser gem
        bot_user_agents = ['googlebot', 'bingbot']
        bot_user_agents.each do |bot_user_agent|
          allow(controller.request).to receive(:user_agent).and_return(bot_user_agent)
          request.env['HTTP_REFERER'] = 'http://example.com'
          request.headers['User-Agent'] = bot_user_agent
          stub = stub_request(:get, "#{spec_base_analytics_url}/matomo.php")
            .with(query: hash_including({
              'e_a' => 'DownloadIR',
              'e_c' => 'Unknown',
              'e_n' => file_set.id,
              'e_v' => 'referral',
              'urlref' => 'http://example.com',
              'url' => "http://test.host/downloads/#{file_set.id}"
            }))
            .to_return(status: 200, body: '', headers: {})

          allow(Rails.logger).to receive(:debug)
          expect(Rails.logger).to receive(:debug).with("Bot request detected: #{bot_user_agent}")

          get :show, params: { id: file_set.id }


          # Assert no request is sent to Matomo
          expect(stub).to have_been_requested.times(0)
        end
      end

      it 'sets the medium to direct when there is no referrer' do
        allow(controller).to receive(:cookies) { { _ga: 'ga.1.2.3'} }
        request.env['HTTP_REFERER'] = nil
        stub = stub_request(:get, "#{spec_base_analytics_url}/matomo.php")
        .with(query: hash_including({'e_a' => 'DownloadIR',
                                    'e_c' => 'Unknown',
                                    'e_n' => file_set.id,
                                    'e_v' => 'direct',
                                    'urlref' => nil,
                                    'url' => "http://test.host/downloads/#{file_set.id}"
                                    }))
               .to_return(status: 200, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
      end

      it 'logs an error for a 400 response' do
        allow(Rails.logger).to receive(:error)
        request.env['HTTP_REFERER'] = 'http://example.com'
        stub = stub_request(:get, "#{spec_base_analytics_url}/matomo.php")
        .with(query: hash_including({'e_a' => 'DownloadIR'}))
               .to_return(status: 400, body: '', headers: {})
        get :show, params: { id: file_set }
        expect(stub).to have_been_requested.times(1) # must be after the method call that creates request
        expect(Rails.logger).to have_received(:error).exactly(1).times
      end
    end
  end

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
    context 'with file set for download' do
      let(:file_set) do
        FactoryBot.create(:file_with_work, user: @user, content: File.open("#{fixture_path}/files/image.png"))
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

  describe '#fetch_record' do
    it 'fetches the record from Solr' do
      expect(controller.send(:fetch_record)).to eq(mock_record)
    end
  end

  describe '#fetch_admin_set' do
    it 'fetches the admin set from Solr' do
      expect(controller.send(:fetch_admin_set)).to eq(mock_admin_set)
    end
  end

  describe '#admin_set_id' do
    it 'returns the admin set id' do
      expect(controller.send(:admin_set_id)).to eq('h128zk07m')
    end
  end

  describe '#record_id' do
    it 'returns the record id' do
      expect(controller.send(:record_id)).to eq('1z40m031g')
    end

    it 'returns Unknown if the record is blank' do
      allow(controller).to receive(:fetch_record).and_return([])
      expect(controller.send(:record_id)).to eq('Unknown')
    end
  end

  describe '#fileset_id' do
    it 'returns the fileset id from params' do
      controller.params = { id: file_set.id }
      expect(controller.send(:fileset_id)).to eq(file_set.id)
    end

    it 'returns Unknown if params id is missing' do
      controller.params = {}
      expect(controller.send(:fileset_id)).to eq('Unknown')
    end
  end

  describe '#record_title' do
    it 'returns the record title' do
      expect(controller.send(:record_title)).to eq('Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response')
    end

    it 'returns Unknown if the record title is blank' do
      allow(controller).to receive(:fetch_record).and_return([{ 'title_tesim' => nil }])
      expect(controller.send(:record_title)).to eq('Unknown')
    end
  end

  describe '#site_id' do
    it 'returns the site id from ENV' do
      expect(controller.send(:site_id)).to eq('5')
    end
  end
end
