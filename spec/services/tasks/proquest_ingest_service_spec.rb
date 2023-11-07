# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::ProquestIngestService, :ingest do
  let(:config) {
    {
      'unzip_dir' => 'spec/fixtures/proquest/tmp',
      'package_dir' => 'spec/fixtures/proquest',
      'admin_set' => 'proquest admin set',
      'depositor_onyen' => 'admin',
      'deposit_title' => 'Deposit by ProQuest Depositor via CDR Collector 1.0',
      'deposit_method' => 'CDR Collector 1.0',
      'deposit_type' => 'http://proquest.com'
    }
  }
  let(:admin) { FactoryBot.create(:admin) }

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

  let(:status_service) { Tasks::IngestStatusService.new('spec/fixtures/proquest/tmp/proquest_deposit_status.json') }

  before do
    ActiveFedora::Cleaner.clean!
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    allow(CharacterizeJob).to receive(:perform_later)
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
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
      service = Tasks::ProquestIngestService.new(config, status_service)

      expect(service.temp).to eq 'spec/fixtures/proquest/tmp'
      expect(service.admin_set_id).to eq AdminSet.where(title: 'proquest admin set').first.id
      expect(service.depositor).to be_instance_of(User)

      expect(service.deposit_record_hash).to include({ title: 'ProQuest Ingest 2022-01-31 23:27:21',
                                                       deposit_method: 'Hy-C v1.4.2, Tasks::ProquestIngestService',
                                                       deposit_package_type: 'http://proquest.com',
                                                       deposit_package_subtype: 'ProQuest',
                                                       deposited_by: admin.uid })
      expect(service.package_dir).to eq 'spec/fixtures/proquest'
      expect(service.depositor).to eq(admin)
    end
  end

  describe '#process_all_packages' do
    before do
      Dissertation.delete_all
    end

    it 'ingests proquest records' do
      expect { Tasks::ProquestIngestService.new(config, status_service).process_all_packages }.to change { Dissertation.count }.by(1).and change { DepositRecord.count }.by(1)

      # check embargo information
      dissertation = Dissertation.first

      # first dissertation - embargo code: 3, publication year: 2019
      expect(dissertation['depositor']).to eq admin.uid
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

      statuses = status_service.load_statuses
      expect(statuses.size).to eq 2
      package1 = statuses['proquest-attach0.zip']
      expect(package1['status']).to eq 'Complete'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error']).to be_nil
      # This file is missing metadata
      package1 = statuses['proquest-attach7.zip']
      expect(package1['status']).to eq 'Failed'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error']).to_not be_nil
    end

    context 'with error thrown by process_package' do
      let(:service) { Tasks::ProquestIngestService.new(config, status_service) }
      before do
        allow(service).to receive(:process_package).and_raise('Help')
      end

      it 'records error in outcome' do
        service.process_all_packages

        statuses = status_service.load_statuses
        expect(statuses.size).to eq 2
        package0 = statuses['proquest-attach0.zip']
        expect(package0['status']).to eq 'Failed'
        expect(package0['status_timestamp']).to_not be_nil
        expect(package0['error'][0]['message']).to eq 'Help'
        expect(package0['error'][0]['trace']).to_not be_nil
        package1 = statuses['proquest-attach7.zip']
        expect(package1['status']).to eq 'Failed'
        expect(package1['status_timestamp']).to_not be_nil
        expect(package1['error'][0]['message']).to eq 'Help'
        expect(package1['error'][0]['trace']).to_not be_nil
      end
    end
  end

  # most processing functionality is tested in process_all_packages
  # this test is to make sure only selected packages are processed
  describe '#process_packages' do
    let(:manager) do
      FactoryBot.create(:user, email: 'manager@example.com', guest: false, uid: 'manager')
    end
    let(:manager_agent) { Sipity::Agent.where(proxy_for_id: 'dissertation_manager', proxy_for_type: 'Hyrax::Group').first_or_create }

    before do
      Dissertation.delete_all

      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'group',
                                             agent_id: 'dissertation_manager',
                                             access: 'manage')
      Hyrax::Workflow::PermissionGenerator.call(roles: 'managing', workflow: workflow, agents: manager_agent)
      manager_role = Role.where(name: 'dissertation_manager').first_or_create
      manager_role.users << manager
      manager_role.save
    end

    let(:filepath_array) { ['spec/fixtures/proquest/proquest-attach0.zip'] }
    let(:service) { Tasks::ProquestIngestService.new(config, status_service) }

    it 'ingests selected proquest records' do
      expect { service.process_packages(filepath_array) }.to change { Dissertation.count }.by(1).and change { DepositRecord.count }.by(1)

      statuses = status_service.load_statuses
      expect(statuses.size).to eq 1
      package1 = statuses['proquest-attach0.zip']
      expect(package1['status']).to eq 'Complete'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error']).to be_nil

      # Dissertation and both of its files should have the manager role assigned to it
      dissertation = Dissertation.first
      expect_to_have_manager_permission(dissertation)

      diss_file_sets = dissertation.file_sets
      expect(diss_file_sets.length).to eq 2
      expect_to_have_manager_permission(diss_file_sets[0])
      expect_to_have_manager_permission(diss_file_sets[1])
      expect(diss_file_sets[1].visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    end

    def expect_to_have_manager_permission(item)
      perm = item.permissions.first
      expect(perm.agent.first.id).to eq 'http://projecthydra.org/ns/auth/group#dissertation_manager'
      expect(perm.mode.first.id).to eq 'http://www.w3.org/ns/auth/acl#Write'
    end
  end

  describe '#extract_files' do
    let(:service) { Tasks::ProquestIngestService.new(config, status_service) }
    let(:zip_path) { 'spec/fixtures/proquest/proquest-attach0.zip' }
    let(:unzipped_dir) { service.unzip_dir(zip_path) }

    it 'extracts files from zip' do
      expect(service.unzip_dir(zip_path)).to eq 'spec/fixtures/proquest/tmp/proquest-attach0'
      expect(Dir.entries(unzipped_dir)).to match_array(['.', '..'])
      service.extract_files(zip_path)
      expect(Dir.entries(unzipped_dir)).to match_array(['.', '..', 'attach_unc_1.pdf', 'attach_unc_1_DATA.xml', 'attach_unc_1_attach'])
    end
  end

  describe '#valid_extract?' do
    let(:service) { Tasks::ProquestIngestService.new(config, status_service) }

    context 'with a properly formed package' do
      let(:zip_path) { 'spec/fixtures/proquest/proquest-attach0.zip' }

      it 'returns true' do
        extracted_files = service.extract_files(zip_path)
        expect(service.valid_extract?(extracted_files)).to eq true
      end
    end

    context 'with a package with unexpected contents' do
      let(:zip_path) { 'spec/fixtures/proquest/proquest-attach7.zip' }

      it 'returns false' do
        extracted_files = service.extract_files(zip_path)
        expect(service.valid_extract?(extracted_files)).to eq false
      end
    end
  end

  describe '#ingest_proquest_file' do
    let(:dissertation) { Dissertation.create(title: ['new dissertation']) }
    let(:metadata) { { title: ['new dissertation file'] } }
    let(:file) { 'spec/fixtures/files/test.txt' }

    it 'saves a fileset' do
      expect { Tasks::ProquestIngestService.new(config, status_service).ingest_proquest_file(parent: dissertation, resource: metadata, f: file) }
        .to change { FileSet.count }.by(1)
    end
  end

  describe '#metadata_file_path' do
    let(:service) { Tasks::ProquestIngestService.new(config, status_service) }
    let(:zip_path) { 'spec/fixtures/proquest/proquest-attach0.zip' }
    let(:unzipped_dir) { service.unzip_dir(zip_path) }

    before do
      service.extract_files(zip_path)
    end

    it 'returns the path to the metadata file' do
      expect(service.metadata_file_path(dir: unzipped_dir)).to eq(File.join(unzipped_dir, 'attach_unc_1_DATA.xml'))
    end
  end

  describe '#proquest_metadata' do
    context 'with embargo code 3 and publication year 2019' do
      let(:metadata_file) { 'spec/fixtures/proquest/attach_unc_1_DATA.xml' }

      it 'parses metadata from proquest xml' do
        service = Tasks::ProquestIngestService.new(config, status_service)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => admin.uid,
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2019',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 } },
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
        service = Tasks::ProquestIngestService.new(config, status_service)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => admin.uid,
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2019',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 },
                                                                   '1' => { 'name' => 'Advisor, Jane N', 'index' => 2 } },
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
        service = Tasks::ProquestIngestService.new(config, status_service)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => admin.uid,
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2017',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 } },
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
        service = Tasks::ProquestIngestService.new(config, status_service)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => admin.uid,
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2019',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 } },
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
        service = Tasks::ProquestIngestService.new(config, status_service)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => admin.uid,
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2018',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 } },
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
        service = Tasks::ProquestIngestService.new(config, status_service)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => admin.uid,
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2018',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 } },
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
        service = Tasks::ProquestIngestService.new(config, status_service)
        service.instance_variable_set(:@file_last_modified, Date.parse('2019-11-13'))
        attributes, files = service.proquest_metadata(metadata_file)
        expect(attributes).to include({ 'title' => ['Perspective on Attachments and Ingests'],
                                        'label' => 'Perspective on Attachments and Ingests',
                                        'depositor' => admin.uid,
                                        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
                                        'date_issued' => '2018',
                                        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 } },
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
    let(:service) { Tasks::ProquestIngestService.new(config, status_service) }

    context 'with a department from the controlled vocabulary' do
      let(:department) { 'Philosophy' }

      it 'returns hash for creating a person object including the mapped affiliation' do
        expect(service.build_person_hash(people, department))
          .to eq({ '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 },
                   '1' => { 'name' => 'Advisor, John T.', 'affiliation' => ['Department of Philosophy'], 'index' => 2 } })
      end
    end

    context 'with a nil department' do
      let(:department) { nil }

      it 'returns hash for creating a person object including the mapped affiliation' do
        expect(service.build_person_hash(people, department))
          .to eq({ '0' => { 'name' => 'Smith, Blandy', 'index' => 1 },
                   '1' => { 'name' => 'Advisor, John T.', 'index' => 2 } })
      end
    end

    context 'with an affiliation that does not match the controlled vocabulary' do
      let(:people) { ['Smith, Blandy', 'Advisor, John T.'] }
      let(:department) { 'not-a-department' }

      it 'maps the affiliation to other_affiliation and logs a warning' do
        allow(service.logger).to receive(:warn)
        expect(service.build_person_hash(people, department))
          .to eq({ '0' => { 'name' => 'Smith, Blandy', 'other_affiliation' => 'not-a-department', 'index' => 1 },
                   '1' => { 'name' => 'Advisor, John T.', 'other_affiliation' => 'not-a-department', 'index' => 2 } })

        expect(service.logger).to have_received(:warn).twice.with('Could not map to standard department name: not-a-department')
      end
    end
  end

  describe '#affiliation' do
    context 'when the affiliation is a controlled value' do
      let(:original_affiliation) { 'Philosophy' }
      let(:expected_mapped_affiliation) { ['Department of Philosophy'] }

      it 'returns the mapped affiliation when it matches the controlled vocabulary' do
        expect(Tasks::ProquestIngestService.new(config, status_service).affiliation(original_affiliation)).to eq(expected_mapped_affiliation)
      end
    end

    context 'when the affiliation is not a controlled value' do
      let(:original_affiliation) { 'not-a-department' }

      it 'returns the mapped affiliation when it matches the controlled vocabulary' do
        expect(Tasks::ProquestIngestService.new(config, status_service).affiliation(original_affiliation)).to eq(nil)
      end
    end
  end

  describe '#format_name' do
    let(:xml) { Nokogiri::XML('<DISS_name><DISS_surname>Smith</DISS_surname><DISS_fname>Blandy</DISS_fname><DISS_middle/><DISS_suffix/><DISS_affiliation>University of North Carolina at Chapel Hill</DISS_affiliation></DISS_name>') }

    it 'returns formatted names' do
      expect(Tasks::ProquestIngestService.new(config, status_service).format_name(xml.xpath('//DISS_name').first)).to eq 'Smith, Blandy'
    end
  end

  describe '#file_record' do
    let(:metadata) {
      { 'title' => ['Perspective on Attachments and Ingests'],
        'label' => 'Perspective on Attachments and Ingests',
        'depositor' => admin.uid,
        'creators_attributes' => { '0' => { 'name' => 'Smith, Blandy', 'affiliation' => ['Department of Philosophy'], 'index' => 1 } },
        'date_issued' => '2019',
        'abstract' => 'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
        'advisors_attributes' => { '0' => { 'name' => 'Advisor, John T', 'index' => 1 } },
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
      expect(Tasks::ProquestIngestService.new(config, status_service).file_record(metadata)).to include({ 'date_created' => nil,
                                                                                        'depositor' => admin.uid,
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
