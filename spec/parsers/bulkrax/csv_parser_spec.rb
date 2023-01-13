# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/parsers/bulkrax/csv_parser_override.rb')

# testing overrides
RSpec.describe Bulkrax::CsvParser do
  before do
    ActiveFedora::Cleaner.clean!
  end

  after do
    ActiveFedora::Cleaner.clean!
  end

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

      it 'updates file permissions of uploaded zip file' do
        importer.parser_fields = { import_file_path: zip_file.path }
        importer.save
        upload_dir = "#{Bulkrax.import_path}/#{importer.id}_#{importer.created_at.strftime('%Y%m%d%H%M%S')}"

        # check that zip file was returned
        expect(subject.write_import_file(zip_file)).to eq "#{upload_dir}/bulkrax_import1.zip"

        # check file permissions
        zip_file_permissions = File.stat("#{upload_dir}/bulkrax_import1.zip").mode.to_s(8)[2..5]
        expect(zip_file_permissions).to eq '0644'
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
end
