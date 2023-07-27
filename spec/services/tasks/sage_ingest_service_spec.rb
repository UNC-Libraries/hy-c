# frozen_string_literal: true
require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe Tasks::SageIngestService, :sage, :ingest do
  include ActiveJob::TestHelper

  let(:config) {
    {
      'unzip_dir' => 'spec/fixtures/sage/tmp',
      'package_dir' => 'spec/fixtures/sage',
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
      'depositor_onyen' => 'admin'
    }
  }
  let(:status_service) { Tasks::IngestStatusService.new(File.join(path_to_tmp, 'deposit_status.json')) }
  let(:service) { described_class.new(config, status_service) }

  let(:sage_fixture_path) { File.join(fixture_path, 'sage') }
  let(:path_to_tmp) { FileUtils.mkdir_p(File.join(fixture_path, 'sage', 'tmp')).first }
  let(:first_package_identifier) { 'CCX_2021_28_10.1177_1073274820985792' }
  let(:first_zip_path) { "spec/fixtures/sage/#{first_package_identifier}.zip" }
  let(:first_dir_path) { "spec/fixtures/sage/tmp/#{first_package_identifier}" }
  let(:first_pdf_path) { "#{path_to_tmp}/10.1177_1073274820985792.pdf" }
  let(:first_xml_path) { "#{sage_fixture_path}/#{first_package_identifier}/10.1177_1073274820985792.xml" }
  let(:ingest_progress_log_path) { File.join(Rails.configuration.log_directory, 'sage_progress.log') }
  let(:last_zip_path) { "spec/fixtures/sage/#{last_package_identifier}.zip" }
  let(:last_package_identifier) { 'GSJ_2021_11_1_10.1177_2192568219890573' }

  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end

  let(:admin) { FactoryBot.create(:admin) }

  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end

  before do
    ActiveFedora::Cleaner.clean!
    admin_set
    permission_template
    workflow
    workflow_state
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    # return the FactoryBot admin_set when searching for admin set from config
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
  end

  after do
    FileUtils.remove_entry(path_to_tmp)
  end

  context 'running the background jobs' do
    let(:user) { FactoryBot.create(:admin) }

    before do
      # Stub background jobs that don't do well in CI
      # stub virus checking
      allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
      # stub longleaf job
      allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
      # stub FITS characterization
      allow(CharacterizeJob).to receive(:perform_later)
    end

    around do |example|
      File.open(ingest_progress_log_path, 'w') { |file| file.truncate(0) }
      perform_enqueued_jobs do
        example.run
      end
      File.open(ingest_progress_log_path, 'w') { |file| file.truncate(0) }
    end

    describe '#process_package' do
      let(:original_title) { 'Americas Original Immunization Controversy' }
      let(:updated_title1) { 'America\'s Original Immunization Controversy' }
      let(:updated_title2) { 'America’s Original Immunization Controversy: The Tercentenary of the Boston Smallpox Epidemic of 1721' }
      let(:original_creator) { 'Nakayama, Don' }
      let(:updated_creator) { 'Nakayama, Don K.' }

      context 'revision with no existing work' do
        let(:package_name) { 'ASU_2022_88_10_10.1177_00031348221074228.r2022-12-22.zip' }

        it 'creates the work as if it were new' do
          work_id = nil
          expect { work_id = service.process_package("spec/fixtures/sage/revisions/both_changed/#{package_name}") }
              .to change { Article.count }.by(1)
              .and change { FileSet.count }.by(2)
          work = ActiveFedora::Base.find(work_id)
          expect(work.title.first).to eq updated_title2
          status = status_service.statuses[package_name]
          expect(status['status']).to eq 'In Progress'
          expect(status['error'][0]['message']).to eq "Package #{package_name} indicates that it is a revision, but no existing work with DOI https://doi.org/10.1177/00031348221074228 was found. Creating a new work instead."
          expect(status['error'][0]['trace']).to be_nil
        end
      end

      context 'revision with existing work that does not have expected files' do
        let(:package_name) { 'ASU_2022_88_10_10.1177_00031348221074228.r2022-12-22.zip' }
        let(:work) { FactoryBot.create(:article, identifier: ['https://doi.org/10.1177/00031348221074228']) }

        it 'adds new filesets to the existing work, and sets warnings' do
          work_id = work.id
          expect { service.process_package("spec/fixtures/sage/revisions/both_changed/#{package_name}") }
              .to change { Article.count }.by(0)
              .and change { FileSet.count }.by(2)
          work = ActiveFedora::Base.find(work_id)
          file_sets = work.file_sets
          xml_fs = file_sets.detect { |fs| fs.label.end_with?('.xml') }
          pdf_fs = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
          expect(xml_fs.present?).to be_truthy
          expect(pdf_fs.present?).to be_truthy
          status = status_service.statuses[package_name]
          expect(status['status']).to eq 'In Progress'
          expect(status['error'].length).to eq 2
          expect(status['error'][0]['message']).to eq "Package #{package_name} is a revision but did not have an existing XML file. Adding new file."
          expect(status['error'][0]['trace']).to be_nil
          expect(status['error'][1]['message']).to eq "Package #{package_name} is a revision but did not have an existing PDF file. Adding new file."
          expect(status['error'][1]['trace']).to be_nil
        end
      end

      context 'with existing work' do
        before do
          @work_id = service.process_package('spec/fixtures/sage/revisions/new/ASU_2022_88_10_10.1177_00031348221074228.zip')
        end

        context 'revision indicating xml changed' do
          it 'updates the xml, title and creator name' do
            work = ActiveFedora::Base.find(@work_id)
            expect(work.title.first).to eq original_title
            creators = work.creators.to_a
            expect(creators.length).to eq 1
            expect(creators[0].name.first).to eq original_creator
            file_sets = work.file_sets
            xml_fs = file_sets.detect { |fs| fs.label.end_with?('.xml') }
            xml_date_modified = xml_fs.date_modified
            pdf_fs = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
            pdf_date_modified = pdf_fs.date_modified

            expect { service.process_package('spec/fixtures/sage/revisions/metadata_changed/ASU_2022_88_10_10.1177_00031348221074228.r2022-12-19.zip') }
                .to change { Article.count }.by(0)
                .and change { FileSet.count }.by(0)
            work = ActiveFedora::Base.find(@work_id)
            expect(work.title.first).to eq updated_title1
            creators = work.creators.to_a
            expect(creators.length).to eq 1
            expect(creators[0].name.first).to eq updated_creator
            file_sets = work.file_sets
            xml_fs2 = file_sets.detect { |fs| fs.label.end_with?('.xml') }
            pdf_fs2 = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
            expect(pdf_fs2.date_modified).to eq (pdf_date_modified)
            expect(xml_fs2.date_modified).not_to eq (xml_date_modified)
          end
        end

        context 'revision indicating the pdf changed' do
          it 'updates only the pdf' do
            work = ActiveFedora::Base.find(@work_id)
            file_sets = work.file_sets
            xml_fs = file_sets.detect { |fs| fs.label.end_with?('.xml') }
            xml_date_modified = xml_fs.date_modified
            pdf_fs = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
            pdf_date_modified = pdf_fs.date_modified

            expect { service.process_package('spec/fixtures/sage/revisions/file_changed/ASU_2022_88_10_10.1177_00031348221074228.r2022-12-20.zip') }
                .to change { Article.count }.by(0)
                .and change { FileSet.count }.by(0)
            work = ActiveFedora::Base.find(@work_id)
            expect(work.title.first).to eq original_title
            file_sets = work.file_sets
            xml_fs2 = file_sets.detect { |fs| fs.label.end_with?('.xml') }
            pdf_fs2 = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
            expect(pdf_fs2.date_modified).not_to eq (pdf_date_modified)
            expect(xml_fs2.date_modified).to eq (xml_date_modified)
          end
        end

        context 'revision indicating xml and pdf changed' do
          it 'updates the pdf, xml and metadata' do
            work = ActiveFedora::Base.find(@work_id)
            expect(work.title.first).to eq original_title
            file_sets = work.file_sets
            xml_fs = file_sets.detect { |fs| fs.label.end_with?('.xml') }
            xml_date_modified = xml_fs.date_modified
            pdf_fs = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
            pdf_date_modified = pdf_fs.date_modified

            expect { service.process_package('spec/fixtures/sage/revisions/both_changed/ASU_2022_88_10_10.1177_00031348221074228.r2022-12-22.zip') }
                .to change { Article.count }.by(0)
                .and change { FileSet.count }.by(0)
            work = ActiveFedora::Base.find(@work_id)
            expect(work.title.first).to eq updated_title2
            file_sets = work.file_sets
            xml_fs2 = file_sets.detect { |fs| fs.label.end_with?('.xml') }
            pdf_fs2 = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
            expect(pdf_fs2.date_modified).not_to eq (pdf_date_modified)
            expect(xml_fs2.date_modified).not_to eq (xml_date_modified)
          end
        end

        context 'new work with the same DOI' do
          let(:package_name) { 'ASU_2022_88_10_10.1177_00031348221074228.zip' }

          it 'skips the duplicate work and records an error' do
            expect { service.process_package("spec/fixtures/sage/revisions/new/#{package_name}") }
                .to raise_error("Work #{@work_id} already exists with DOI https://doi.org/10.1177/00031348221074228, skipping package #{package_name}")
                .and change { Article.count }.by(0)
                .and change { FileSet.count }.by(0)
          end
        end
      end
    end

    # most processing functionality is tested in process_package
    # this test is to make sure only selected packages are processed
    describe '#process_packages' do
      it 'processes selected package' do
        expect { service.process_packages([first_zip_path]) }
            .to change { Article.count }.by(1)
        statuses = status_service.load_statuses
        expect(statuses.size).to eq 1
      end

      it 'processes multiple selected packages' do
        expect { service.process_packages([first_zip_path, last_zip_path]) }
            .to change { Article.count }.by(2)
        statuses = status_service.load_statuses
        expect(statuses.size).to eq 2
      end
    end
  end

  context 'without running the background jobs' do
    # empty the progress log
    around do |example|
      File.open(ingest_progress_log_path, 'w') { |file| file.truncate(0) }
      example.run
      File.open(ingest_progress_log_path, 'w') { |file| file.truncate(0) }
    end

    describe '#initialize' do
      it 'sets parameters from the configuration file' do
        stub_const('BRANCH', 'v1.4.2')
        allow(Time).to receive(:new).and_return(Time.parse('2022-01-31 23:27:21'))
        expect(service.package_dir).to eq 'spec/fixtures/sage'
        expect(service.depositor).to be_instance_of(User)
        expect(service.deposit_record_hash).to eq({ title: 'Sage Ingest 2022-01-31 23:27:21',
                                                    deposit_method: 'Hy-C v1.4.2, Tasks::SageIngestService',
                                                    deposit_package_type: 'https://sagepub.com',
                                                    deposit_package_subtype: 'https://jats.nlm.nih.gov/publishing/',
                                                    deposited_by: admin.uid })
        expect(service.depositor).to eq(admin)
        expect(service.ingest_progress_log).to be_instance_of(Migrate::Services::ProgressTracker)
        expect(service.ingest_source).to eq('Sage')
      end

      it 'has a default admin set' do
        expect(service.admin_set).to eq admin_set
        expect(service.admin_set.title).to eq ['Open_Access_Articles_and_Book_Chapters']
      end

      it 'has a default admin set' do
        expect(service.admin_set).to eq admin_set
        expect(service.admin_set.title).to eq ['Open_Access_Articles_and_Book_Chapters']
      end

      it 'creates a progress log for the ingest' do
        expect(service.ingest_progress_log).to be_instance_of(Migrate::Services::ProgressTracker)
      end
    end

    describe '#unzip_dir' do
      it 'determines the directory to unzip the files to based on the zipfile path' do
        expect(service.unzip_dir(first_zip_path)).to eq('spec/fixtures/sage/tmp/CCX_2021_28_10.1177_1073274820985792')
      end
    end
    # rubocop:disable Layout/MultilineMethodCallIndentation
    it 'can run a wrapper method' do
      expect(File.foreach(ingest_progress_log_path).count).to eq 0
      expect do
        service.process_all_packages
      end.to change { Article.count }.by(5)
         .and change { FileSet.count }.by(10)
         .and change { Sipity::Entity.count }.by(5)
         .and change { DepositRecord.count }.by(1)
      expect(File.foreach(ingest_progress_log_path).count).to eq 5
    end
    # rubocop:enable Layout/MultilineMethodCallIndentation

    context 'when it cannot find the depositor' do
      before do
        # return nil when searching for the depositor
        allow(User).to receive(:find_by).with(uid: 'admin').and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.new(config, status_service) }.to raise_error(ActiveRecord::RecordNotFound, 'Could not find User with onyen admin')
      end
    end

    context 'when it cannot find the admin_set' do
      before do
        allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.new(config, status_service) }.to raise_error(ActiveRecord::RecordNotFound, 'Could not find AdminSet with title Open_Access_Articles_and_Book_Chapters')
      end
    end

    describe '#extract_files' do
      let(:unzipped_dir) { service.unzip_dir(first_zip_path) }

      it 'takes a path to a zip file as an argument' do
        expect(Dir.entries(unzipped_dir)).to match_array(['.', '..'])
        service.extract_files(first_zip_path)
        expect(Dir.entries(unzipped_dir)).to match_array(['.', '..', '10.1177_1073274820985792.pdf', '10.1177_1073274820985792.xml'])
      end
    end

    it 'writes to the log' do
      logger = spy('logger')
      allow(Logger).to receive(:new).and_return(logger)
      described_class.new(config, status_service)
      expect(logger).to have_received(:info).with('Beginning Sage ingest')
    end

    context 'with a log directory configured' do
      it 'can write to the configured log path when it is an absolute path' do
        allow(Rails.configuration).to receive(:log_directory).and_return('/some/absolute/path/')

        logger = spy('logger')
        allow(Logger).to receive(:new).and_return(logger)

        expect(Logger).to receive(:new).with('/some/absolute/path/sage_ingest.log', { progname: 'Sage ingest' })
        described_class.new(config, status_service)
      end

      it 'can write to the configured log path when it is a relative path' do
        allow(Rails.configuration).to receive(:log_directory).and_return('some/relative/path/')

        logger = spy('logger')
        allow(Logger).to receive(:new).and_return(logger)

        expect(Logger).to receive(:new).with('some/relative/path/sage_ingest.log', { progname: 'Sage ingest' })
        described_class.new(config, status_service)
      end
    end

    context 'with a package including a manifest' do
      let(:package_path) { File.join(fixture_path, 'sage', 'AJH_2021_38_4_10.1177_1049909120951088.zip') }
      let(:unzipped_dir) { service.unzip_dir(package_path) }

      it 'correctly identifies the manifest and jats xml' do
        file_names = service.extract_files(package_path).keys
        expect(service.metadata_file_path(file_names: file_names, dir: unzipped_dir)).to eq(File.join(unzipped_dir, '10.1177_1049909120951088.xml'))
      end
    end

    context 'with unexpected contents in the package' do
      let(:package_path) { File.join(fixture_path, 'sage', 'quadruple_package.zip') }

      it 'logs an error' do
        logger = spy('logger')
        allow(Logger).to receive(:new).and_return(logger)
        service.extract_files(package_path)
        expect(logger).to have_received(:error).with("Unexpected package contents - 4 files extracted from #{package_path}")
      end

      it 'does not validate the extracted packages' do
        extracted_files = service.extract_files(package_path)
        expect(service.valid_extract?(extracted_files)).to eq false
      end
    end

    it 'only creates a single deposit record per service instance' do
      expect do
        service.deposit_record
        service.deposit_record
      end.to change { DepositRecord.count }.by(1)
    end
  end
end
