require 'rails_helper'

RSpec.describe Tasks::ProquestIngestService, :ingest do
  let(:args) { { configuration_file: 'spec/fixtures/proquest/proquest_config.yml' } }

  let(:admin_set) do
    AdminSet.create(title: ['proquest admin set'],
                    description: ['some description'])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  before do
    allow(CharacterizeJob).to receive(:perform_later)
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
    allow(Date).to receive(:today).and_return(Date.parse('2019-09-12'))
    AdminSet.delete_all
    Sipity::WorkflowState.create(workflow_id: workflow.id, name: 'deposited')
  end

  after do
    FileUtils.rm_rf(Dir.glob('spec/fixtures/proquest/tmp/*'))
  end

  describe '#initialize' do
    it 'sets all params' do
      allow(Time).to receive(:new).and_return(Time.parse('2022-01-31 23:27:21'))
      stub_const('BRANCH', 'v1.4.2')
      service = Tasks::ProquestIngestService.new(args)

      expect(service.temp).to eq 'spec/fixtures/proquest/tmp'
      expect(service.admin_set_id).to eq AdminSet.where(title: 'proquest admin set').first.id
      expect(service.depositor).to be_instance_of(User)

      expect(service.deposit_record_hash).to include({ title: 'ProQuest Ingest January 31, 2022',
                                                       deposit_method: 'Hy-C v1.4.2, Tasks::ProquestIngestService',
                                                       deposit_package_type: 'http://proquest.com',
                                                       deposit_package_subtype: 'ProQuest',
                                                       deposited_by: 'admin' })
      expect(service.package_dir).to eq 'spec/fixtures/proquest'
    end
  end

  describe '#process_packages' do
    before do
      Dissertation.delete_all
    end

    it 'ingests proquest records' do
      allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
      expect { Tasks::ProquestIngestService.new(args).process_packages }.to change { Dissertation.count }.by(1).and change { DepositRecord.count }.by(1)

      # check embargo information
      dissertation = Dissertation.first

      # first dissertation - embargo code: 3, publication year: 2019
      expect(dissertation['depositor']).to eq 'admin'
      expect(dissertation['title']).to match_array ['Perspective on Attachments and Ingests']
      expect(dissertation['label']).to eq 'Perspective on Attachments and Ingests'
      expect(dissertation['date_issued']).to eq '2019'
      expect(dissertation['creators'][0]['name']).to match_array ['Smith, Blandy']
      expect(dissertation['keyword']).to match_array ['Philosophy', 'attachments', 'aesthetics']
      expect(dissertation['resource_type']).to match_array ['Dissertation']
      expect(dissertation['abstract']).to match_array ['The purpose of this study is to test ingest of a proquest deposit object without any attachments']
      expect(dissertation['advisors'][0]['name']).to match_array ['Advisor, John T']
      expect(dissertation['degree']).to eq 'Doctor of Philosophy'
      expect(dissertation['degree_granting_institution']).to eq 'University of North Carolina at Chapel Hill Graduate School'
      expect(dissertation['dcmi_type']).to match_array ['http://purl.org/dc/dcmitype/Text']
      expect(dissertation['graduation_year']).to eq '2019'
      expect(dissertation['rights_statement_label']).to eq 'In Copyright - Educational Use Permitted'
      expect(dissertation.visibility).to eq 'restricted'
      expect(dissertation.embargo_release_date).to eq (Date.today.to_datetime + 2.years)
    end
  end

  describe '#extract_files' do
    it 'extracts files from zip' do
      expect(Tasks::ProquestIngestService.new(args).extract_files('spec/fixtures/proquest/proquest-attach0.zip'))
        .to eq 'spec/fixtures/proquest/tmp/proquest-attach0'
    end
  end

  describe '#ingest_proquest_file' do
    let(:dissertation) { Dissertation.create(title: ['new dissertation']) }
    let(:metadata) { { title: ['new dissertation file'] } }
    let(:file) { 'spec/fixtures/files/test.txt' }

    it 'saves a fileset' do
      allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
      expect { Tasks::ProquestIngestService.new(args).ingest_proquest_file(parent: dissertation, resource: metadata, f: file) }
        .to change { FileSet.count }.by(1)
    end
  end

  describe '#proquest_metadata' do
    context 'with embargo code 3 and publication year 2019' do
      let(:metadata_file) { 'spec/fixtures/proquest/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(args)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => 'admin',
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2019',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 } },
                                        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
                                        'degree' => 'Doctor of Philosophy',
                                        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
                                        'graduation_year' => '2019',
                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                        'resource_type' => 'Dissertation',
                                        'visibility' => 'restricted',
                                        'embargo_release_date' => '2021-09-12',
                                        'visibility_during_embargo' => 'restricted',
                                        'visibility_after_embargo' => 'open',
                                        'admin_set_id' => AdminSet.where(title: 'proquest admin set').first.id })
        expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
      end
    end

    context 'with embargo code 2 and publication year 2019' do
      let(:metadata_file) { 'spec/fixtures/proquest/proquest-attach1/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(args)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => 'admin',
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2019',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 },
                                                                   '1' => { 'name' => 'Advisor, Jane N', 'affiliation' => nil, 'index' => 2 } },
                                        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
                                        'degree' => 'Master of Arts',
                                        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
                                        'graduation_year' => '2019',
                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                        'resource_type' => 'Masters Thesis',
                                        'visibility' => 'restricted',
                                        'embargo_release_date' => '2020-09-12',
                                        'visibility_during_embargo' => 'restricted',
                                        'visibility_after_embargo' => 'open',
                                        'admin_set_id' => AdminSet.where(title: 'proquest admin set').first.id })
        expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
      end
    end

    context 'with embargo code 3 and publication year 2017' do
      let(:metadata_file) { 'spec/fixtures/proquest/proquest-attach2/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(args)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => 'admin',
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2017',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 } },
                                        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
                                        'degree' => 'Doctor of Philosophy',
                                        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
                                        'graduation_year' => '2017',
                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                        'resource_type' => 'Dissertation',
                                        'visibility' => 'restricted',
                                        'embargo_release_date' => '2019-12-31',
                                        'visibility_during_embargo' => 'restricted',
                                        'visibility_after_embargo' => 'open',
                                        'admin_set_id' => AdminSet.where(title: 'proquest admin set').first.id })
        expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
      end
    end

    context 'with embargo code 4 and publication year 2019' do
      let(:metadata_file) { 'spec/fixtures/proquest/proquest-attach3/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(args)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => 'admin',
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2019',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 } },
                                        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
                                        'degree' => 'Doctor of Philosophy',
                                        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
                                        'graduation_year' => '2019',
                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                        'resource_type' => 'Dissertation',
                                        'visibility' => 'restricted',
                                        'embargo_release_date' => '2021-09-12',
                                        'visibility_during_embargo' => 'restricted',
                                        'visibility_after_embargo' => 'open',
                                        'admin_set_id' => AdminSet.where(title: 'proquest admin set').first.id })
        expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
      end
    end

    context 'with embargo code 0 and publication year 2018' do
      let(:metadata_file) { 'spec/fixtures/proquest/proquest-attach4/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(args)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => 'admin',
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2018',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 } },
                                        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
                                        'degree' => 'Doctor of Philosophy',
                                        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
                                        'graduation_year' => '2018',
                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                        'resource_type' => 'Dissertation',
                                        'visibility' => 'open',
                                        'visibility_during_embargo' => 'restricted',
                                        'visibility_after_embargo' => 'open',
                                        'admin_set_id' => AdminSet.where(title: 'proquest admin set').first.id })
        expect(attributes['embargo_release_date']).to be_nil
        expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
      end
    end

    context 'with embargo code 4 and publication year 2018' do
      let(:metadata_file) { 'spec/fixtures/proquest/proquest-attach5/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(args)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => 'admin',
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2018',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 } },
                                        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
                                        'degree' => 'Doctor of Philosophy',
                                        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
                                        'graduation_year' => '2018',
                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                        'resource_type' => 'Dissertation',
                                        'visibility' => 'restricted',
                                        'embargo_release_date' => '2020-12-31',
                                        'visibility_during_embargo' => 'restricted',
                                        'visibility_after_embargo' => 'open',
                                        'admin_set_id' => AdminSet.where(title: 'proquest admin set').first.id })
        expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
      end
    end

    context 'with embargo code 2 and publication year 2018' do
      let(:metadata_file) { 'spec/fixtures/proquest/proquest-attach6/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(args)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => 'admin',
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2018',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 } },
                                        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
                                        'degree' => 'Doctor of Philosophy',
                                        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
                                        'graduation_year' => '2018',
                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                        'resource_type' => 'Dissertation',
                                        'visibility' => 'restricted',
                                        'embargo_release_date' => '2019-12-31',
                                        'visibility_during_embargo' => 'restricted',
                                        'visibility_after_embargo' => 'open',
                                        'admin_set_id' => AdminSet.where(title: 'proquest admin set').first.id })
        expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
      end
    end
  end

  describe '#build_person_hash' do
    let(:people) { ['Smith, Blandy', 'Advisor, John T.'] }
    let(:affiliation) { 'Department of Philosophy' }

    it 'returns hash for creating a person object' do
      expect(Tasks::ProquestIngestService.new(args).build_person_hash(people, affiliation)).to include({ '0' => { 'name' => 'Smith, Blandy', 'affiliation' => 'Department of Philosophy', 'index' => 1 },
                                                                                                         '1' => { 'name' => 'Advisor, John T.', 'affiliation' => 'Department of Philosophy', 'index' => 2 } })
    end
  end

  describe '#format_name' do
    let(:xml) { Nokogiri::XML('<DISS_name><DISS_surname>Smith</DISS_surname><DISS_fname>Blandy</DISS_fname><DISS_middle/><DISS_suffix/><DISS_affiliation>University of North Carolina at Chapel Hill</DISS_affiliation></DISS_name>') }

    it 'returns formatted names' do
      expect(Tasks::ProquestIngestService.new(args).format_name(xml.xpath('//DISS_name').first)).to eq 'Smith, Blandy'
    end
  end

  describe '#file_record' do
    let(:metadata) {
      { 'title' => ['Perspective on Attachments and Ingests'],
        'label' => 'Perspective on Attachments and Ingests',
        'depositor' => 'admin',
        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
        'date_issued' => '2019',
        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'affiliation' => nil, 'index' => 1 } },
        'dcmi_type' => 'http://purl.org/dc/dcmitype/Text',
        'degree' => 'Doctor of Philosophy',
        'degree_granting_institution' => 'University of North Carolina at Chapel Hill Graduate School',
        'graduation_year' => '2019',
        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
        'resource_type' => 'Dissertation',
        'visibility' => 'restricted',
        'embargo_release_date' => '2021-11-13',
        'visibility_during_embargo' => 'restricted',
        'visibility_after_embargo' => 'open' }
    }

    it 'returns fileset metadata' do
      expect(Tasks::ProquestIngestService.new(args).file_record(metadata)).to include({ 'date_created' => nil,
                                                                                        'depositor' => 'admin',
                                                                                        'embargo_release_date' => '2021-11-13',
                                                                                        'keyword' => ['aesthetics', 'attachments', 'Philosophy'],
                                                                                        'label' => 'Perspective on Attachments and Ingests',
                                                                                        'language' => ['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                                                                        'resource_type' => ['Dissertation'],
                                                                                        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                                                                        'title' => ['Perspective on Attachments and Ingests'],
                                                                                        'visibility' => 'restricted',
                                                                                        'visibility_after_embargo' => 'open',
                                                                                        'visibility_during_embargo' => 'restricted' })
    end
  end
end
