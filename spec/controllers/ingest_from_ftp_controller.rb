# frozen_string_literal: true
require 'rails_helper'

RSpec.describe IngestFromFtpController, type: :controller do

  let(:proquest_dir) { Dir.mktmpdir }
  let(:sage_dir) { Dir.mktmpdir }
  let(:valid_session) { {} }

  around do |example|
    cached_proquest = ENV['INGEST_PROQUEST_PATH']
    cached_sage = ENV['INGEST_SAGE_PATH']
    ENV['INGEST_PROQUEST_PATH'] = proquest_dir.to_s
    ENV['INGEST_SAGE_PATH'] = sage_dir.to_s
    example.run
    ENV['INGEST_PROQUEST_PATH'] = cached_proquest
    ENV['INGEST_SAGE_PATH'] = cached_sage
  end

  after do
    FileUtils.rm_rf(proquest_dir)
    FileUtils.rm_rf(sage_dir)
  end

  let!(:proquest_package1) { File.join(proquest_dir, 'etdadmin_upload_3806.zip') }
  let!(:proquest_package2) { File.join(proquest_dir, 'etdadmin_upload_942402.zip') }
  let!(:sage_package1) { File.join(sage_dir, '1177_01605976231158397.zip') }
  let!(:sage_package2) { File.join(sage_dir, 'JPX_2021_8_10.1177_23743735211067313.r2022-01-21.zip') }

  before do
    File.open(proquest_package1, 'w') {}
    File.open(proquest_package2, 'w') {}
    File.open(sage_package1, 'w') {}
    File.open(sage_package2, 'w') {}
  end

  describe 'GET #list_packages' do
    context 'as an admin' do

      before do
        allow(controller).to receive(:authorize!).with(:read, :admin_dashboard).and_return(true)
      end

      it 'proquest provider returns proquest results' do
        get :list_packages, params: { provider: 'proquest'}, session: valid_session
        expect(response).to be_successful
        package_results = subject.instance_variable_get('@package_results')

        expect(package_results.length).to eq 2
        expect(package_results[0][:filename]).to eq 'etdadmin_upload_3806.zip'
        expect(package_results[0][:last_modified]).to be_a Time
        expect(package_results[1][:filename]).to eq 'etdadmin_upload_942402.zip'
        expect(package_results[1][:last_modified]).to be_a Time
        expect(subject.instance_variable_get('@needs_revision_flag')).to be_falsey
      end

      it 'sage provider returns sage results' do
        get :list_packages, params: { provider: 'sage'}, session: valid_session
        expect(response).to be_successful
        package_results = subject.instance_variable_get('@package_results')

        expect(package_results.length).to eq 2
        expect(package_results[0][:filename]).to eq '1177_01605976231158397.zip'
        expect(package_results[0][:last_modified]).to be_a Time
        expect(package_results[0][:is_revision]).to be_falsey
        expect(package_results[1][:filename]).to eq 'JPX_2021_8_10.1177_23743735211067313.r2022-01-21.zip'
        expect(package_results[1][:last_modified]).to be_a Time
        expect(package_results[1][:is_revision]).to be_truthy
        expect(subject.instance_variable_get('@needs_revision_flag')).to be_truthy
      end
    end

    context 'as a non-admin' do
      it 'returns an unauthorized response' do
        get :list_packages, params: {}, session: valid_session
        expect(response).to redirect_to new_user_session_path
      end
    end
  end
end
