# frozen_string_literal: true
require 'rails_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe DeregisterLongleafJob, type: :job do
  describe '.perform' do
    let(:job) { DeregisterLongleafJob.new }
    let(:longleaf_api_url) { 'https://longleaf.api.com' }
    let(:filepath) { File.join(fixture_path, 'hyrax/hyrax_test4.pdf') }
    let(:repository_file) do
      Hydra::PCDM::File.new.tap do |f|
        f.content = File.open(filepath)
        f.original_name = 'test.pdf'
        f.mime_type = 'application/pdf'
        f.save!
      end
    end
    let(:checksum) { repository_file.checksum.value }
    let(:fedora_file_path) {
      File.join(fixture_path, checksum.scan(/.{2}/)[0..2].join('/'), checksum)
    }

    around do |example|
      cached_api_host_path = ENV['LONGLEAF_API_HOST_PATH']
      cached_storage_path = ENV['LONGLEAF_STORAGE_PATH']
      ENV['LONGLEAF_API_HOST_PATH'] = longleaf_api_url
      ENV['LONGLEAF_STORAGE_PATH'] = fixture_path
      example.run
      ENV['LONGLEAF_API_HOST_PATH'] = cached_api_host_path
      ENV['LONGLEAF_STORAGE_PATH'] = cached_storage_path
    end

    context 'deregistration is successful' do
      let(:body) do
        {'event' => 'deregister',
         'success' => [fedora_file_path],
         'failure' => []
        }
      end
      let(:longleaf_response) { double('response', code: 200, body: body.to_json.to_s) }

      it 'hits the Longleaf api' do
        allow(HTTParty).to receive(:delete).and_return(longleaf_response)

        job.perform(repository_file.checksum.value)
        expect(HTTParty).to have_received(:delete).with(longleaf_api_url + '/api/deregister',
                                                      headers: { "Content-Type": 'application/json' },
                                                      body:  { file: fedora_file_path }.to_json,
                                                      format: :json)
      end

      it 'logs the success' do
        allow(HTTParty).to receive(:delete).and_return(longleaf_response)
        allow(Rails.logger).to receive(:info)

        job.perform(repository_file.checksum.value)
        expect(Rails.logger).to have_received(:info).with("Successfully deregistered #{fedora_file_path}")
      end

    end

    context 'deregistration failed' do
      let(:body) do
        {'event': 'deregister',
         'success': [],
         'failure': [fedora_file_path]
        }
      end
      let(:longleaf_response) { double('response', code: 200, body: body.to_json.to_s) }

      it 'hits the Longleaf api' do
        allow(HTTParty).to receive(:delete).and_return(longleaf_response)

        expect { job.perform(checksum) }.to raise_error(
          "Failed to deregister #{fedora_file_path} to Longleaf. Status code #{longleaf_response.code}, response body: #{longleaf_response.body}")
        expect(HTTParty).to have_received(:delete).with(longleaf_api_url + '/api/deregister',
                                                      headers: { "Content-Type": 'application/json' },
                                                      body:  { file: fedora_file_path }.to_json,
                                                      format: :json)
      end

      it 'raises error' do
        allow(HTTParty).to receive(:delete).and_return(longleaf_response)
        allow(Rails.logger).to receive(:error)

        expect { job.perform(checksum) }.to raise_error(
          "Failed to deregister #{fedora_file_path} to Longleaf. Status code #{longleaf_response.code}, response body: #{longleaf_response.body}")
        expect(Rails.logger).to have_received(:error).with(
          "Failed to deregister #{fedora_file_path} to Longleaf. Status code #{longleaf_response.code}, response body: #{longleaf_response.body}")
      end
    end

    context 'deregistration API returned error' do
      let(:longleaf_response) { double('response', code: 500, body: nil) }

      it 'hits the Longleaf api and raises an error' do
        allow(HTTParty).to receive(:delete).and_return(longleaf_response)

        expect { job.perform(checksum) }
          .to raise_error("Longleaf deregister API returned status 500 for #{fedora_file_path}")
        expect(HTTParty).to have_received(:delete).with(longleaf_api_url + '/api/deregister',
                                                      headers: { "Content-Type": 'application/json' },
                                                      body:  { file: fedora_file_path }.to_json,
                                                      format: :json)
      end

      it 'logs the error' do
        allow(HTTParty).to receive(:delete).and_return(longleaf_response)
        allow(Rails.logger).to receive(:error)

        expect { job.perform(checksum) }
          .to raise_error("Longleaf deregister API returned status 500 for #{fedora_file_path}")
        expect(Rails.logger).to have_received(:error)
                                  .with("Longleaf deregister API returned status 500 for #{fedora_file_path}")
      end
    end
  end
end
