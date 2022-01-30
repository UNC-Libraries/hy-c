require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe Tasks::SageIngestService, :sage, :ingest do
  include ActiveJob::TestHelper

  let(:service) { described_class.new(configuration_file: path_to_config) }

  let(:sage_fixture_path) { File.join(fixture_path, 'sage') }
  let(:path_to_config) { File.join(sage_fixture_path, 'sage_config.yml') }
  let(:path_to_tmp) { FileUtils.mkdir_p(File.join(fixture_path, 'sage', 'tmp')).first }
  let(:first_package_identifier) { 'CCX_2021_28_10.1177_1073274820985792' }
  let(:first_zip_path) { "spec/fixtures/sage/#{first_package_identifier}.zip" }
  let(:first_dir_path) { "spec/fixtures/sage/tmp/#{first_package_identifier}" }
  let(:first_pdf_path) { "#{path_to_tmp}/10.1177_1073274820985792.pdf" }
  let(:first_xml_path) { "#{sage_fixture_path}/#{first_package_identifier}/10.1177_1073274820985792.xml" }
  let(:ingest_progress_log_path) { File.join(sage_fixture_path, 'ingest_progress.log') }

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
    let(:ingest_work) { JatsIngestWork.new(xml_path: first_xml_path) }
    let(:built_article) { service.article_with_metadata(ingest_work) }
    let(:user) { FactoryBot.create(:admin) }

    before do
      # Stub background jobs that don't do well in CI
      # stub virus checking
      allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
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

    it 'attaches a file to the file_set' do
      service.extract_files(first_zip_path, path_to_tmp)
      service.attach_file_set_to_work(work: built_article, dir: path_to_tmp, file_name: '10.1177_1073274820985792.pdf', user: user, visibility: 'open')
      fs = built_article.file_sets.first
      expect(fs.files.first).to be_instance_of(Hydra::PCDM::File)
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
        expect(service.deposit_record_hash).to eq({ title: 'Sage Ingest January 31, 2022',
                                                    deposit_method: 'Hy-C v1.4.2, Tasks::SageIngestService',
                                                    deposit_package_type: 'https://sagepub.com',
                                                    deposit_package_subtype: 'https://jats.nlm.nih.gov/publishing/',
                                                    deposited_by: admin.uid })
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
    # rubocop:disable Layout/MultilineMethodCallIndentation
    it 'can run a wrapper method' do
      expect(File.foreach(ingest_progress_log_path).count).to eq 0
      expect do
        service.process_packages
      end.to change { Article.count }.by(5)
         .and change { FileSet.count }.by(10)
         .and change { Sipity::Entity.count }.by(5)
         .and change { DepositRecord.count }.by(1)
      expect(File.foreach(ingest_progress_log_path).count).to eq 5
    end
    # rubocop:enable Layout/MultilineMethodCallIndentation

    context 'with an ingest work object' do
      let(:ingest_work) { JatsIngestWork.new(xml_path: first_xml_path) }
      let(:built_article) { service.article_with_metadata(ingest_work) }
      let(:user) { FactoryBot.create(:admin) }

      it 'can create a valid article' do
        expect do
          service.article_with_metadata(ingest_work)
        end.to change { Article.count }.by(1)
      end

      it 'returns a valid article' do
        expect(built_article).to be_instance_of Article
        expect(built_article.persisted?).to be true
        expect(built_article.valid?).to be true
        # These values are also tested via the edit form in spec/features/edit_sage_ingested_works_spec.rb
        expect(built_article.title).to eq(['Inequalities in Cervical Cancer Screening Uptake Between Chinese Migrant Women and Local Women: A Cross-Sectional Study'])
        first_creator = built_article.creators.find { |creator| creator[:index] == ['1'] }
        expect(first_creator.attributes['name']).to match_array(['Holt, Hunter K.'])
        expect(first_creator.attributes['other_affiliation']).to match_array(['Department of Family and Community Medicine, University of California, San Francisco, CA, USA'])
        expect(first_creator.attributes['orcid']).to match_array(['https://orcid.org/0000-0001-6833-8372'])
        expect(built_article.abstract).to include(/Efforts to increase education opportunities, provide insurance/)
        expect(built_article.date_issued).to eq('2021-02-01')
        expect(built_article.copyright_date).to eq('2021')
        expect(built_article.dcmi_type).to match_array(['http://purl.org/dc/dcmitype/Text'])
        expect(built_article.funder).to match_array(['Fogarty International Center'])
        expect(built_article.identifier).to match_array(['https://doi.org/10.1177/1073274820985792'])
        expect(built_article.issn).to match_array(['1073-2748'])
        expect(built_article.journal_issue).to be nil
        expect(built_article.journal_title).to eq('Cancer Control')
        expect(built_article.journal_volume).to eq('28')
        expect(built_article.keyword).to match_array(['HPV', 'HPV knowledge and awareness', 'cervical cancer screening', 'migrant women', 'China'])
        expect(built_article.license).to match_array(['http://creativecommons.org/licenses/by-nc/4.0/'])
        expect(built_article.license_label).to match_array(['Attribution-NonCommercial 4.0 International'])
        expect(built_article.publisher).to match_array(['SAGE Publications'])
        expect(built_article.resource_type).to match_array(['Article'])
        expect(built_article.rights_holder).to include(/SAGE Publications Inc, unless otherwise noted. Manuscript/)
        expect(built_article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
        expect(built_article.rights_statement_label).to eq('In Copyright')
        expect(built_article.visibility).to eq('open')
        expect(built_article.deposit_record).to be
      end

      it 'puts the work in an admin_set' do
        expect(built_article.admin_set).to be_instance_of(AdminSet)
        expect(built_article.admin_set.title).to eq(admin_set.title)
      end

      it 'attaches a pdf file_set to the article' do
        service.extract_files(first_zip_path, path_to_tmp)
        expect do
          service.attach_file_set_to_work(work: built_article, dir: path_to_tmp, file_name: '10.1177_1073274820985792.pdf', user: user, visibility: 'open')
        end.to change { FileSet.count }.by(1)
        expect(built_article.file_sets).to be_instance_of(Array)
        fs = built_article.file_sets.first
        expect(fs).to be_instance_of(FileSet)
        expect(fs.depositor).to eq(user.uid)
        expect(fs.visibility).to eq(built_article.visibility)
        expect(fs.parent).to eq(built_article)
      end

      it 'attaches an xml file_set to the article' do
        service.extract_files(first_zip_path, path_to_tmp)
        expect do
          service.attach_file_set_to_work(work: built_article, dir: path_to_tmp, file_name: '10.1177_1073274820985792.xml', user: user, visibility: 'restricted')
        end.to change { FileSet.count }.by(1)
        expect(built_article.file_sets).to be_instance_of(Array)
        fs = built_article.file_sets.first
        expect(fs).to be_instance_of(FileSet)
        expect(fs.depositor).to eq(user.uid)
        expect(fs.visibility).to eq('restricted')
        expect(fs.parent).to eq(built_article)
      end
    end

    context 'when it cannot find the depositor' do
      before do
        # return nil when searching for the depositor
        allow(User).to receive(:find_by).with(uid: 'admin').and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.new(configuration_file: path_to_config) }.to raise_error(ActiveRecord::RecordNotFound, 'Could not find User with onyen admin')
      end
    end

    context 'when it cannot find the admin_set' do
      before do
        allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.new(configuration_file: path_to_config) }.to raise_error(ActiveRecord::RecordNotFound, 'Could not find AdminSet with title Open_Access_Articles_and_Book_Chapters')
      end
    end

    describe '#extract_files' do
      it 'takes a path to a zip file and a temp directory as arguments' do
        service.extract_files(first_zip_path, path_to_tmp)
        expect(Dir.entries(path_to_tmp)).to match_array(['.', '..', '10.1177_1073274820985792.pdf', '10.1177_1073274820985792.xml'])
      end
    end

    it 'writes to the log' do
      logger = spy('logger')
      allow(Logger).to receive(:new).and_return(logger)
      described_class.new(configuration_file: path_to_config)
      expect(logger).to have_received(:info).with('Beginning Sage ingest')
    end

    context 'with a log directory configured' do
      it 'can write to the configured log path when it is an absolute path' do
        allow(Rails.configuration).to receive(:log_directory).and_return('/some/absolute/path/')

        logger = spy('logger')
        allow(Logger).to receive(:new).and_return(logger)

        expect(Logger).to receive(:new).with('/some/absolute/path/sage_ingest.log', { progname: 'Sage ingest' })
        described_class.new(configuration_file: path_to_config)
      end

      it 'can write to the configured log path when it is a relative path' do
        allow(Rails.configuration).to receive(:log_directory).and_return('some/relative/path/')

        logger = spy('logger')
        allow(Logger).to receive(:new).and_return(logger)

        expect(Logger).to receive(:new).with('some/relative/path/sage_ingest.log', { progname: 'Sage ingest' })
        described_class.new(configuration_file: path_to_config)
      end
    end

    context 'with a package including a manifest' do
      let(:package_path) { File.join(fixture_path, 'sage', 'AJH_2021_38_4_10.1177_1049909120951088.zip') }

      it 'correctly identifies the manifest and jats xml' do
        file_names = service.extract_files(package_path, path_to_tmp).keys
        expect(service.jats_xml_path(file_names: file_names, dir: path_to_tmp)).to eq(File.join(path_to_tmp, '10.1177_1049909120951088.xml'))
      end
    end

    context 'with unexpected contents in the package' do
      let(:path_to_tmp) { Dir.mktmpdir }
      let(:package_path) { File.join(fixture_path, 'sage', 'quadruple_package.zip') }

      it 'logs an error' do
        logger = spy('logger')
        allow(Logger).to receive(:new).and_return(logger)
        service.extract_files(package_path, path_to_tmp)
        expect(logger).to have_received(:error).with("Unexpected package contents - 4 files extracted from #{package_path}")
      end
    end
  end
end
