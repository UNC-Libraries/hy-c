require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe Tasks::SageIngestService do
  let(:path_to_config) { File.join(fixture_path, "sage", "sage_config.yml") }
  let(:path_to_tmp) { File.join(fixture_path, "sage", "tmp") }
  let(:first_package_identifier) { 'CCX_2021_28_10.1177_1073274820985792' }
  let(:first_zip_path) { "spec/fixtures/sage/#{first_package_identifier}.zip" }
  let(:first_dir_path) { "spec/fixtures/sage/tmp/#{first_package_identifier}" }
  let(:first_pdf_path) { "#{first_dir_path}/10.1177_1073274820985792.pdf" }
  let(:first_done_file_path) { File.join(first_dir_path, '.done.pdf') }
  let(:first_done_xml_path) { File.join(first_dir_path, '.done.xml') }

  describe '#initialize' do
    let(:service) { described_class.new(configuration_file: path_to_config) }
    after do
      FileUtils.rm_rf(Dir["#{path_to_tmp}/*"])
    end

    it "sets parameters from the configuration file" do
      expect(service.package_dir).to eq "spec/fixtures/sage"
      expect(service.unzip_dir).to eq "spec/fixtures/sage/tmp"
    end

    it 'can run a wrapper method' do
      expect do
        service.process_packages
      end.to change { Dir.entries(path_to_tmp).count }.from(3).to(7) # The three are ".", "..", and ".keep"
      expect(File.exist?(first_pdf_path)).to eq true
      expect(File.exist?(first_done_file_path)).to eq true
      expect(File.exist?(first_done_xml_path)).to eq true
    end

    context "with a package already unzipped" do
      before do
        service.extract_files(first_zip_path)
      end
      it 'can write a .done file to the created directory' do
        expect(Dir.exist?(first_dir_path)).to be true
        expect(Dir.glob("#{first_dir_path}/*").count).to eq 2
        expect do
          service.mark_done(first_dir_path, 'pdf')
        end.to change { Dir.entries(first_dir_path).count }.from(4).to(5)
        expect(File.exist?(first_done_file_path)).to be true
        expect do
          service.mark_done(first_dir_path, 'xml')
        end.to change { Dir.entries(first_dir_path).count }.from(5).to(6)
        expect(File.exist?(first_done_xml_path)).to be true
      end
    end


    context "with an unzipped file already present" do
      before do
        Dir.mkdir(first_dir_path)
        FileUtils.touch(first_pdf_path)
      end

      it "logs to the rails log" do
        allow(Rails.logger).to receive(:info)
        service.extract_files(first_zip_path)
        expect(Rails.logger).to have_received(:info).with("#{first_zip_path}, zip file error: Destination '#{first_pdf_path}' already exists")
      end
    end

    context "with the 'done' file already present" do
      before do
        freeze_time
        Dir.mkdir(first_dir_path)
        FileUtils.touch(first_done_file_path)
      end
      it "logs that the file is already complete" do
        allow(Rails.logger).to receive(:info)
        service.process_packages
        expect(Rails.logger).to have_received(:info).with("#{first_dir_path} .done.pdf already present. File last modified #{Time.now}.")
      end
    end

    context "with unexpected contents in the package" do
      it "logs an error" do
        allow(Rails.logger).to receive(:error)
        allow(service).to receive(:extract_files).and_return({"pdf_name" => "a", "xml_name" => "b"})
        allow(service).to receive(:extract_files).with(first_zip_path).and_return({"pdf_name" => "a", "xml_name" => "b", "unexpected_file_name"=> "c"})
        service.process_packages
        expect(Rails.logger).to have_received(:error).with("Unexpected package contents - more than two files extracted from #{first_zip_path}")
      end
    end
  end
end
