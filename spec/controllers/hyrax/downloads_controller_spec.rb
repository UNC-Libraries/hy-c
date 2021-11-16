require 'rails_helper'

RSpec.describe Hyrax::DownloadsController, type: :controller do
  # app/controllers/concerns/hyrax/download_analytics_behavior.rb:8
  describe '#track_download' do
    before do
      Hyrax.config.google_analytics_id = 'blah'
      stub_request(:post, "http://www.google-analytics.com/collect").to_return(status: 200, body: "", headers: {})
    end

    it "has the method for tracking analytics for download" do
      expect(controller).to respond_to(:track_download)
      expect(controller.track_download).to be_a_kind_of Net::HTTPOK
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
end
