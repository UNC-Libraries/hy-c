# frozen_string_literal: true
require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe FileSetRemediationService do
  let(:file_set_without_file) { FactoryBot.create(:file_set, title: ['Should not have file']) }
  let(:file_set_with_file) { FactoryBot.create(:file_set, :with_original_file, title: ['Should have file']) }
  let(:service) { described_class.new }
  let(:work_without_file) { FactoryBot.create(:article, title: ['Work without file']) }
  let(:work_with_file) { FactoryBot.create(:article, title: ['Work with file']) }
  let(:work_without_file_set) { FactoryBot.create(:article, title: ['Work without file_set']) }
  let(:file_set_without_file_without_parent) { FactoryBot.create(:file_set, title: ['Should not have file or parent']) }

  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
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
    before do
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
      work_without_file.ordered_members << file_set_without_file
      work_without_file.save!
      work_with_file.ordered_members << file_set_with_file
      work_with_file.save!
      work_without_file_set
      file_set_without_file_without_parent
    end

    it 'writes file_sets without files to a csv' do
      expect(File.exist?(csv_path)).to eq false
      service.create_csv_of_file_sets_without_files
      expect(File.exist?(csv_path)).to eq true
      csv = CSV.parse(File.read(csv_path), headers: true)
      expect(csv.headers).to match_array(['file_set_id', 'file_set_url', 'parent_id', 'parent_url'])
      expect(csv.length).to eq(2)
      expect(csv.first.to_h).to eq({ 'file_set_id' => file_set_without_file.id,
                                     'file_set_url' => "#{ENV['HYRAX_HOST']}/concern/file_sets/#{file_set_without_file.id}",
                                     'parent_id' => work_without_file.id,
                                     'parent_url' => "#{ENV['HYRAX_HOST']}/concern/articles/#{work_without_file.id}" })
      expect(csv[1].to_h).to eq({ 'file_set_id' => file_set_without_file_without_parent.id,
                                  'file_set_url' => "#{ENV['HYRAX_HOST']}/concern/file_sets/#{file_set_without_file_without_parent.id}",
                                  'parent_id' => nil,
                                  'parent_url' => nil })
    end
  end
end
