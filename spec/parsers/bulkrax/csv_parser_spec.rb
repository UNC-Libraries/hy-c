# frozen_string_literal: true
require 'rails_helper'

# testing overrides
RSpec.describe Bulkrax::CsvParser do
  let(:user) do
    User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false) }
  end

  context 'importer actions' do
    let(:importer) do
      Bulkrax::Importer.new(name: 'CSV importer',
                            admin_set_id: 'AdminSet',
                            user: user,
                            frequency: 'PT0S',
                            parser_klass: 'Bulkrax::CsvParser',
                            parser_fields: {},
                            field_mapping: {})
    end

    subject { described_class.new(importer) }

    describe '#write_import_file' do
      let(:csv_file) { Rack::Test::UploadedFile.new(file_fixture('importer1.csv')) }
      let(:zip_file) { Rack::Test::UploadedFile.new(file_fixture('bulkrax_import1.zip')) }

      it 'updates the file permissions of an uploaded csv file' do
        importer.parser_fields = { import_file_path: csv_file.path }
        importer.save
        upload_dir = "#{Bulkrax.import_path}/#{importer.id}_#{importer.created_at.strftime('%Y%m%d%H%M%S')}"

        # check that csv file was returned
        expect(subject.write_import_file(csv_file)).to eq "#{upload_dir}/importer1.csv"

        # check file permissions
        csv_file_permissions = File.stat("#{upload_dir}/importer1.csv").mode.to_s(8)[2..5]
        expect(csv_file_permissions).to eq '0644'
      end

      it 'returns the csv file from a zip file and updates file permissions' do
        importer.parser_fields = { import_file_path: zip_file.path }
        importer.save
        upload_dir = "#{Bulkrax.import_path}/#{importer.id}_#{importer.created_at.strftime('%Y%m%d%H%M%S')}"

        # check that files were unzipped
        expect(subject.write_import_file(zip_file)).to eq "#{upload_dir}/importer1.csv"
        expect(Dir.glob("#{upload_dir}/files/*")).to eq ["#{upload_dir}/files/test.txt"]

        # check file permissions
        zip_file_permissions = File.stat("#{upload_dir}/bulkrax_import1.zip").mode.to_s(8)[2..5]
        csv_file_permissions = File.stat("#{upload_dir}/importer1.csv").mode.to_s(8)[2..5]
        txt_file_permissions = File.stat("#{upload_dir}/files/test.txt").mode.to_s(8)[2..5]
        expect(zip_file_permissions).to eq '0644'
        expect(csv_file_permissions).to eq '0644'
        expect(txt_file_permissions).to eq '0644'
      end
    end

    describe '#unzip' do
      let(:zip_file) { file_fixture('bulkrax_import1.zip') }

      it 'unzips files to specified directory' do
        importer.save
        upload_dir = "#{Bulkrax.import_path}/#{importer.id}_#{importer.created_at.strftime('%Y%m%d%H%M%S')}"
        described_class.new(importer).unzip(zip_file, upload_dir)

        expect(Dir.glob("#{upload_dir}/**/*")).to include("#{upload_dir}/importer1.csv", "#{upload_dir}/files/test.txt")
      end
    end

    describe '#write_partial_import_file' do
      let(:corrected_file) { Rack::Test::UploadedFile.new(file_fixture('importer1_corrected_entries.csv')) }

      it 'returns corrected_entries file in import directory' do
        importer.parser_fields = { import_file_path: corrected_file.path }
        importer.save
        upload_dir = "#{Bulkrax.import_path}/#{importer.id}_#{importer.created_at.strftime('%Y%m%d%H%M%S')}"

        # check that file was moved
        expect(subject.write_import_file(corrected_file)).to eq "#{upload_dir}/importer1_corrected_entries.csv"

        # check file permissions
        corrected_file = File.stat("#{upload_dir}/importer1_corrected_entries.csv").mode.to_s(8)[2..5]
        expect(corrected_file).to eq '0644'
      end
    end
  end

  context 'exporter actions' do
    let(:exporter) do
      Bulkrax::Exporter.new(name: 'CSV exporter',
                            user: user,
                            export_type: 'metadata',
                            export_from: 'worktype',
                            export_source: 'General',
                            parser_klass: 'Bulkrax::CsvParser',
                            limit: 1,
                            field_mapping: nil)
    end

    let(:exporter_run) do
      Bulkrax::ExporterRun.new(exporter: exporter,
                               total_work_entries: 1,
                               enqueued_records: 1,
                               processed_records: 0,
                               deleted_records: 0,
                               failed_records: 0)
    end

    let(:test_work) do
      General.new(title: ['new test bulkrax work'],
                  creators_attributes: { '0' => { 'name' => 'Doe, John', 'affiliation' => 'Department of Biology', 'orcid' => 'some orcid' } })
    end

    before do
      General.delete_all
    end

    subject { described_class.new(exporter) }

    describe '#write_files' do
      it 'exports people objects' do
        test_work.save
        exporter_run.save
        exporter.export
        export_file = subject.setup_export_file
        subject.write_files

        first_row = CSV.read(export_file, headers: true).first
        expect(first_row['source_identifier']).to eq test_work.id
        expect(first_row['title']).to eq test_work.title.first
        expect(first_row['creators_attributes']).to eq "{\"0\"=>#{test_work.creators.first.as_json}}"
      end
    end

    describe '#export_headers' do
      it 'includes columns for people objects' do
        exporter_run.save
        exporter.export

        expect(subject.export_headers).to include('advisors_attributes', 'arrangers_attributes', 'composers_attributes',
                                                  'contributors_attributes', 'creators_attributes',
                                                  'project_directors_attributes', 'researchers_attributes',
                                                  'reviewers_attributes', 'translators_attributes')
      end
    end
  end
end
