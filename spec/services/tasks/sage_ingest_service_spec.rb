require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe Tasks::SageIngestService, :sage do
  let(:service) { described_class.new(configuration_file: path_to_config) }

  let(:sage_fixture_path) { File.join(fixture_path, "sage") }
  let(:path_to_config) { File.join(sage_fixture_path, "sage_config.yml") }
  let(:path_to_tmp) { File.join(sage_fixture_path, "tmp") }
  let(:first_package_identifier) { 'CCX_2021_28_10.1177_1073274820985792' }
  let(:first_zip_path) { "spec/fixtures/sage/#{first_package_identifier}.zip" }
  let(:first_dir_path) { "spec/fixtures/sage/tmp/#{first_package_identifier}" }
  let(:first_pdf_path) { "#{path_to_tmp}/10.1177_1073274820985792.pdf" }
  let(:first_xml_path) { "#{sage_fixture_path}/#{first_package_identifier}/10.1177_1073274820985792.xml" }
  let(:ingest_progress_log_path) { File.join(sage_fixture_path, "ingest_progress.log") }
  let(:admin) { FactoryBot.create(:admin) }

  let(:admin_set) do
    AdminSet.create(title: ['sage admin set'],
                    description: ['some description'])
  end

  before do
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    # instantiate the sage ingest admin_set
    admin_set
  end

  # empty the progress log
  around do |example|
    File.open(ingest_progress_log_path, 'w') {|file| file.truncate(0) }
    example.run
    File.open(ingest_progress_log_path, 'w') {|file| file.truncate(0) }
  end

  describe '#initialize' do
    it "sets parameters from the configuration file" do
      expect(service.package_dir).to eq "spec/fixtures/sage"
      expect(service.admin_set).to be_instance_of(AdminSet)
      expect(service.depositor).to be_instance_of(User)
    end

    it 'creates a progress log for the ingest' do
      expect(service.ingest_progress_log).to be_instance_of(Migrate::Services::ProgressTracker)
    end
  end

  it 'can run a wrapper method' do
    expect(File.foreach(ingest_progress_log_path).count).to eq 0
    expect do
      service.process_packages
    end.to change { Article.count }.by(4)
    expect(File.foreach(ingest_progress_log_path).count).to eq 4
  end

  context 'with an ingest work object' do
    let(:ingest_work) { JatsIngestWork.new(xml_path: first_xml_path) }
    let(:built_article) { service.article_with_metadata(ingest_work) }
    let(:temp_dir) { Dir.mktmpdir }
    let(:user) { FactoryBot.create(:admin) }

    after do
      FileUtils.remove_entry(temp_dir)
    end

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
      expect(first_creator.attributes['name']).to match_array(["Holt, Hunter K."])
      expect(first_creator.attributes['other_affiliation']).to match_array(['Department of Family and Community Medicine, University of California, San Francisco, CA, USA'])
      expect(first_creator.attributes['orcid']).to match_array(['https://orcid.org/0000-0001-6833-8372'])
      expect(built_article.abstract).to include(/Efforts to increase education opportunities, provide insurance/)
      expect(built_article.date_issued).to eq('2021-02-01')
      expect(built_article.copyright_date).to eq('2021')
      expect(built_article.dcmi_type).to match_array(["http://purl.org/dc/dcmitype/Text"])
      expect(built_article.funder).to match_array(['Fogarty International Center'])
      expect(built_article.identifier).to match_array(['https://doi.org/10.1177/1073274820985792'])
      expect(built_article.issn).to match_array(['1073-2748'])
      expect(built_article.journal_issue).to be nil
      expect(built_article.journal_title).to eq('Cancer Control')
      expect(built_article.journal_volume).to eq('28')
      expect(built_article.keyword).to match_array(['HPV', 'HPV knowledge and awareness', 'cervical cancer screening', 'migrant women', 'China'])
      expect(built_article.license).to match_array(["http://creativecommons.org/licenses/by-nc/4.0/"])
      expect(built_article.license_label).to match_array(['Attribution-NonCommercial 4.0 International'])
      expect(built_article.publisher).to match_array(['SAGE Publications'])
      expect(built_article.resource_type).to match_array(['Article'])
      expect(built_article.rights_holder).to include(/SAGE Publications Inc, unless otherwise noted. Manuscript/)
      expect(built_article.rights_statement).to eq("http://rightsstatements.org/vocab/InC/1.0/")
      expect(built_article.visibility).to eq('open')
    end

    it 'puts the work in an admin_set' do
      expect(built_article.admin_set).to be_instance_of(AdminSet)
      expect(built_article.admin_set.title).to eq(admin_set.title)
    end

    it 'attaches a file_set to the article' do
      service.extract_files(first_zip_path, temp_dir)
      expect do
        service.attach_file_set_to_work(work: built_article, dir: temp_dir, pdf_file_name: '10.1177_1073274820985792.pdf', user: user)
      end.to change { FileSet.count }.by(1)
      expect(built_article.file_sets).to be_instance_of(Array)
      expect(built_article.file_sets.first).to be_instance_of(FileSet)
    end
  end

  describe '#extract_files' do
    let(:temp_dir) { Dir.mktmpdir }

    after do
      FileUtils.remove_entry(temp_dir)
    end
    it 'takes a path to a zip file and a temp directory as arguments' do
      service.extract_files(first_zip_path, temp_dir)
      expect(Dir.entries(temp_dir)).to match_array([".", "..", "10.1177_1073274820985792.pdf", "10.1177_1073274820985792.xml"])
    end
  end

  context "with a package already unzipped" do
    it 'can write to the progress log' do
      allow(service).to receive(:package_ingest_complete?).and_return(true)
      expect(File.size(ingest_progress_log_path)).to eq 0
      service.mark_done(first_package_identifier)
      expect(File.read(ingest_progress_log_path).chomp).to eq "CCX_2021_28_10.1177_1073274820985792"
    end
  end

  context "with an unzipped file already present" do
    before do
      FileUtils.touch(first_pdf_path)
    end

    after do
      FileUtils.rm_rf(Dir["#{path_to_tmp}/*"])
    end

    it "logs to the rails log" do
      allow(Rails.logger).to receive(:info)
      service.extract_files(first_zip_path, path_to_tmp)
      expect(Rails.logger).to have_received(:info).with("#{first_zip_path}, zip file error: Destination '#{first_pdf_path}' already exists")
    end
  end

  context "with unexpected contents in the package" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:package_path) { File.join(fixture_path, "sage", "triple_package.zip") }

    it "logs an error" do
      allow(Rails.logger).to receive(:error)
      service.extract_files(package_path, temp_dir)
      expect(Rails.logger).to have_received(:error).with("Unexpected package contents - more than two files extracted from #{package_path}")
    end
  end
end
