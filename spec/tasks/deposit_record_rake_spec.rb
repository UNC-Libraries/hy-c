# no further tests will be added for this task unless it is needed again in the future

require "rails_helper"
require "rake"

describe "rake deposit_record:migrate", type: :task do
  let(:output_dir) { Dir.mktmpdir }

  before do
    Hyrax::Application.load_tasks if Rake::Task.tasks.empty?
  end

  after do
    FileUtils.remove_entry_secure output_dir
  end

  it "preloads the Rails environment" do
    expect(Rake::Task['deposit_record:migrate'].prerequisites).to include "environment"
  end

  it "creates a new work" do
    expect {
      Rake::Task['deposit_record:migrate'].invoke('spec/fixtures/deposit_record/config.yml',
                                                  output_dir.to_s,
                                                  'spec/fixtures/migration/dr_mapping.csv',
                                                  'RAILS_ENV=test')
    }
      .to change { DepositRecord.count }.by(1)
    new_record = DepositRecord.all[-1]
    expect(new_record['title']).to eq 'Deposit by Biomed Central Depositor via SWORD 1.3'
    expect(new_record['deposit_method']).to eq 'SWORD 1.3'
    expect(new_record['deposit_package_subtype']).to eq 'BiomedCentral'
    expect(new_record['deposit_package_type']).to be_nil
    expect(new_record['deposited_by']).to eq 'CDR Admin'
    expect(new_record['manifest']).not_to be_nil
    expect(new_record['premis']).not_to be_nil
  end
end
