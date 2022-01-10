require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe Tasks::SageIngestService do
  let(:service) { described_class.new(configuration_file: path_to_config) }

  let(:path_to_config) { File.join(fixture_path, "sage", "sage_config.yml") }
  let(:path_to_tmp) { File.join(fixture_path, "sage", "tmp") }
  let(:first_package_identifier) { 'CCX_2021_28_10.1177_1073274820985792' }
  let(:first_zip_path) { "spec/fixtures/sage/#{first_package_identifier}.zip" }
  let(:first_dir_path) { "spec/fixtures/sage/tmp/#{first_package_identifier}" }
  let(:first_pdf_path) { "#{path_to_tmp}/10.1177_1073274820985792.pdf" }
  let(:ingest_progress_log_path) { File.join(fixture_path, "sage", "ingest_progress.log") }

  let(:admin_set) do
    AdminSet.create(title: ['sage admin set'],
                    description: ['some description'])
  end

  before do
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
      expect(service.admin_set_id).to be
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
