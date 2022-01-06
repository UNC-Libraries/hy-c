require 'rails_helper'

RSpec.describe Tasks::CsvIngestService do
  let(:args) { {configuration_file: 'spec/fixtures/csv/csv_ingest_config.yml'} }

  describe '#initialize' do
    it 'sets all params' do
      service = Tasks::CsvIngestService.new(args)

      expect(service.config).to include('work_type' => 'General',
                                        'admin_set' => 'csv default',
                                        'batch_name' => 'CSV',
                                        'depositor_onyen' => 'admin',
                                        'metadata_dir' => 'spec/fixtures/csv/',
                                        'metadata_file' => 'test_data.csv',
                                        'progress_log' => 'spec/fixtures/csv/csv_ingest_completed.log',
                                        'skipped_log' => 'spec/fixtures/csv/csv_ingest_skipped.log',
                                        'deposit_title' => 'CSV deposit',
                                        'deposit_method' => 'rake task',
                                        'deposit_type' => 'a type',
                                        'deposit_subtype' => 'a subtype',
                                        'deposit_record_id_log' => 'spec/fixtures/csv/csv_deposit_record_id.log',
                                        'work_visibility' => 'open',
                                        'file_visibility' => 'open'
                                       )
    end
  end

  describe '#ingest' do
    let(:admin_user) do
      User.find_by_user_key('admin')
    end

    let(:time) do
      Time.now
    end

    let(:admin_set) do
      AdminSet.create!(title: ["csv default"],
                       description: ["some description"])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
    end

    let(:workflow) do
      Sipity::Workflow.create!(name: 'test', allows_access_grant: true, active: true,
                               permission_template_id: permission_template.id)
    end

    before do
      AdminSet.delete_all
      Hyrax::PermissionTemplateAccess.delete_all
      Hyrax::PermissionTemplate.delete_all
      Hyrax::PermissionTemplateAccess.create!(permission_template: permission_template,
                                              agent_type: 'user',
                                              agent_id: admin_user.user_key,
                                              access: 'deposit')
      Sipity::WorkflowAction.create(name: 'show', workflow_id: workflow.id)
    end

    after do
      File.delete('spec/fixtures/csv/csv_ingest_completed.log')
      File.delete('spec/fixtures/csv/csv_ingest_skipped.log')
      File.delete('spec/fixtures/csv/csv_deposit_record_id.log')
    end

    it "creates a new work" do
      expect { Tasks::CsvIngestService.new(args).ingest }.to change{ General.count }.by(1)
                                                                        .and change{ DepositRecord.count }.by(1)
      new_general = General.all[-1]
      expect(new_general['depositor']).to eq 'admin'
      expect(new_general['title']).to match_array ['The Elusiveness of Tolerance: The “Jewish Question” From Lessing to the Napoleonic Wars']
      expect(new_general['label']).to eq 'The Elusiveness of Tolerance: The “Jewish Question” From Lessing to the Napoleonic Wars'
      expect(new_general['date_issued']).to eq ['1997']
      expect(new_general['isbn']).to eq ['9780000000000']
      expect(new_general['creators'][0]['name']).to eq ['Erspamer, Peter R.']
      expect(new_general['resource_type']).to match_array ['Book']
      expect(new_general['series']).to match_array ['UNC Studies in the Germanic Languages and Literatures']
      expect(new_general['language']).to match_array ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(new_general['language_label']).to match_array ['English']
      expect(new_general['license']).to match_array ['http://creativecommons.org/licenses/by-nc-nd/3.0/us/']
      expect(new_general['license_label']).to match_array ['Attribution-NonCommercial-NoDerivs 3.0 United States']
      expect(new_general['abstract']).to match_array ["Peter Erspamer explores the 'Jewish question' in German literature from Lessing's \"Nathan der Weise\" in 1779 to Sessa's \"Unser Verkehr\" in 1815. He analyzes the transition from an enlightened emancipatory literature advocating tolerance in the late eighteenth century to an anti-Semitic literature with nationalistic overtones in the early nineteenth century.

Erspamer examines \"Nathan\" in light of Lessing's attempts to distance himself from the excesses of his own Christian in-group through pariah identification, using an idealized member of an out-group religion as a vehicle to attack the dominant religion. He also focuses on other leading advocates of tolerance and explores changes in Jewish identity, particularly the division of German Jewry into orthodox Jews, adherents of the Haskalah, and converted Jews."]
      expect(new_general['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(new_general['rights_statement_label']).to eq 'In Copyright'
      expect(new_general['subject']).to eq ['German Literature', 'Jewish Studies']
      expect(new_general['publisher']).to eq ['University of North Carolina Press']
      expect(new_general['deposit_record']).not_to be_nil
    end
  end
end
