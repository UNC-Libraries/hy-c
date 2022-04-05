require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe FileSetRemediationService do
  let(:file_set_without_file) { FactoryBot.create(:file_set, title: ['Should not have file']) }
  let(:file_set_with_file) { FactoryBot.create(:file_set, :with_original_file, title: ['Should have file']) }
  let(:service) { described_class.new }

  before do
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
    file_set_without_file
    file_set_with_file
  end

  it 'can tell if a FileSet has attached files' do
    expect(service.has_files?(file_set_without_file)).to eq false
    expect(service.has_files?(file_set_with_file)).to eq true
  end

  context 'creating a csv' do
    let(:csv_path) { "#{ENV['DATA_STORAGE']}/reports/file_sets_without_files.csv" }
    after do
      FileUtils.remove_entry(csv_path) if File.exist?(csv_path)
    end

    it 'writes file_sets without files to a csv' do
      expect(File.exist?(csv_path)).to eq false
      service.create_csv_of_file_sets_without_files
      expect(File.exist?(csv_path)).to eq true
      csv = CSV.parse(File.read(csv_path), headers: true)
      expect(csv.headers).to match_array(['file_set_id', 'url'])
      expect(csv.length).to eq(1)
      expect(csv.first.to_h).to eq({ 'file_set_id' => file_set_without_file.id,
                                     'url' => "#{ENV['HYRAX_HOST']}/concern/file_sets/#{file_set_without_file.id}" })
    end
  end
end
