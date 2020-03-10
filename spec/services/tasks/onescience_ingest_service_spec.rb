require 'rails_helper'

RSpec.describe Tasks::OnescienceIngestService do
  let(:args) { {configuration_file: 'spec/fixtures/onescience/onescience_config.yml'} }

  describe '#initialize' do
    it 'sets all params' do
      service = Tasks::OnescienceIngestService.new(args)

      expect(service.config).to include('work_type' => 'Article',
                                         'admin_set' => 'onescience default',
                                         'depositor_onyen' => 'admin',
                                         'metadata_dir' => 'spec/fixtures/onescience',
                                         'metadata_file' => '1science_test_data.xlsx',
                                         'affiliation_files' => ['1science_sheet1_2016-2018_processed.xlsx',
                                                             '1science_sheet2_2016-2018_processed.xlsx',
                                                             '1science_sheets3-6_2016_2018only_processed.xlsx'],
                                         'embargo_file' => '1science_2016-2018_embargoes.csv',
                                         'pdf_dir' => 'spec/fixtures/onescience',
                                         'progress_log' => 'spec/fixtures/onescience/1science_completed.log',
                                         'skipped_log' => 'spec/fixtures/onescience/1science_skipped.log',
                                         'deposit_title' => 'OneScience deposit 2016-2018',
                                         'deposit_method' => 'rake task',
                                         'deposit_type' => 'a type',
                                         'deposit_subtype' => 'a subtype',
                                         'deposit_record_id_log' => 'spec/fixtures/onescience/1science_deposit_record_id.log',
                                         'scopus_xml_file' => 'scopus-1-science-abstract.xml',
                                         'mapped_scopus_affiliations' => 'scoups_departments-mapped.csv'
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
      AdminSet.create!(title: ["onescience default"],
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
      File.delete('spec/fixtures/onescience/1science_completed.log')
      File.delete('spec/fixtures/onescience/1science_deposit_record_id.log')
    end

    it "creates a new work" do
      expect { Tasks::OnescienceIngestService.new(args).ingest }.to change{ Article.count }.by(1)
                                                                        .and change{ DepositRecord.count }.by(1)
      new_article = Article.all[-1]
      expect(new_article['depositor']).to eq 'admin'
      expect(new_article['title']).to match_array ['A Multi-Institutional Longitudinal Faculty Development Program in Humanism Supports the Professional Development of Faculty Teachers:']
      expect(new_article['label']).to eq 'A Multi-Institutional Longitudinal Faculty Development Program in Humanism Supports the Professional Development of Faculty Teachers:'
      expect(new_article['date_issued']).to eq '2017'
      expect(["Osterberg, Lars G.", "Frankel, Richard M.", "Branch, William T.", "Gilligan, MaryAnn C.",
              "Plews-Ogan, Margaret", "Dunne, Dana", "Hafler, Janet P.", "Litzelman, Debra K.", "Rider, Elizabeth A.",
              "Weil, Amy B.", "Derse, Arthur R.", "May, Natalie B."]).to include (new_article['creators'][0]['name'].first)
      expect(new_article['resource_type']).to match_array ['Article']
      expect(new_article['abstract']).to match_array ['The authors describe the first 11 academic years (2005–2006 through 2016–2017) of a longitudinal, small-group faculty development program for strengthening humanistic teaching and role modeling at 30 U.S. and Canadian medical schools that continues today. During the yearlong program, small groups of participating faculty met twice monthly with a local facilitator for exercises in humanistic teaching, role modeling, and related topics that combined narrative reflection with skills training using experiential learning techniques. The program focused on the professional development of its participants. Thirty schools participated; 993 faculty, including some residents, completed the program.']
      expect(new_article['dcmi_type']).to match_array ['http://purl.org/dc/dcmitype/Text']
      expect(new_article['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(new_article['deposit_record']).not_to be_nil
    end
  end

  describe '#load_data' do
    it 'loads onescience data' do
      service = Tasks::OnescienceIngestService.new(args).load_data
      expect(service[0]['Title']).to eq 'A Multi-Institutional Longitudinal Faculty Development Program in Humanism Supports the Professional Development of Faculty Teachers:'
    end
  end

  describe '#create_deposit_record' do
    it 'creates a deposit record for the onescience ingest batch' do
      expect { Tasks::OnescienceIngestService.new(args).create_deposit_record }.to change{ DepositRecord.count }.by(1)
    end
  end

  describe '#parse_onescience_metadata' do
    let(:data) { {'Title' => 'An article title', 'onescience_id' => '12345'} }
    it 'parses data for onescience record' do
      service = Tasks::OnescienceIngestService.new(args)
      service.instance_variable_set(:@affiliation_mapping, [{'onescience_id' => '12345', 'lastname_author1' => 'Smith', 'firstname_author1' => 'John'}])
      service.instance_variable_set(:@scopus_hash, {'a doi' =>{'0' => {'name' => 'Smith, John', 'index' => '1'}}})
      service.instance_variable_set(:@deposit_record_id, 'some deposit record id')
      work_attributes, files = service.parse_onescience_metadata(data)
      expect(work_attributes).to include({"identifier"=>["Onescience id: 12345"],
                                       "date_issued"=>"",
                                       "title"=>"An article title",
                                       "label"=>"An article title",
                                       "journal_title"=>nil,
                                       "journal_volume"=>"",
                                       "journal_issue"=>"",
                                       "page_start"=>"",
                                       "page_end"=>"",
                                       "abstract"=>nil,
                                       "creators_attributes"=>{0=>{"name"=>"Smith, John", "orcid"=>nil, "affiliation"=>nil, "index" => 1}},
                                       "resource_type"=>"Article",
                                       "language"=>"http://id.loc.gov/vocabulary/iso639-2/eng",
                                       "language_label"=>"English",
                                       "dcmi_type"=>"http://purl.org/dc/dcmitype/Text",
                                       "admin_set_id"=>nil,
                                       "rights_statement"=>"http://rightsstatements.org/vocab/InC/1.0/",
                                       "rights_statement_label"=>"In Copyright",
                                       "deposit_record"=>'some deposit record id'})
      expect(files).to be {}
    end
  end

  describe '#get_people' do
    it 'creates attribute hashes for people obejcts' do
      service = Tasks::OnescienceIngestService.new(args)
      service.instance_variable_set(:@affiliation_mapping, [{'onescience_id' => '12345', 'lastname_author1' => 'Smith', 'firstname_author1' => 'John'}])
      service.instance_variable_set(:@scopus_hash, {'a doi' => {'0' => {'name' => 'Smith, John', 'index' => '1'}}})
      people = service.get_people('12345', 'a doi')
      expect(people).to include({'0' => {'name' => 'Smith, John', 'index' => '1'}})
    end
  end
end
