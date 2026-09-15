# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/concerns/bulkrax/datatables_behavior_override.rb')

RSpec.describe Bulkrax::DatatablesBehavior, type: :controller do
  controller(ApplicationController) do
    include Bulkrax::DatatablesBehavior # rubocop:disable RSpec/DescribedClass
  end

  let(:view_context_double) { double('view_context') }
  let(:two_day_frequency) { double('frequency', to_seconds: 2.days) }

  before do
    allow(controller).to receive(:view_context).and_return(view_context_double)
    allow(controller).to receive(:status_message_for).and_return('Complete')
    allow(controller).to receive(:importer_util_links).and_return('importer actions')
    allow(controller).to receive(:exporter_util_links).and_return('exporter actions')
    allow(controller).to receive(:download_zip).and_return('download link')
    allow(view_context_double).to receive(:link_to) { |label, _path| label }
    allow(view_context_double).to receive(:importer_path) { |importer| "/importers/#{importer.id}" }
    allow(view_context_double).to receive(:exporter_path) { |exporter| "/exporters/#{exporter.id}" }
  end

  describe '#format_importers' do
    before do
      Bulkrax::Importer.delete_all
      FactoryBot.create(:bulkrax_importer_csv, name: 'Hyc Import')
      FactoryBot.create(:bulkrax_importer_csv, name: 'Hyc Two Import')
      FactoryBot.create(:bulkrax_importer_csv, name: 'Boxy Import')
    end

    it 'uses the provided filtered_count for recordsFiltered' do
      result = controller.send(:format_importers, [Bulkrax::Importer.find_by(name: 'Hyc Import')], 2)

      expect(result[:recordsTotal]).to eq(3)
      expect(result[:recordsFiltered]).to eq(2)
      expect(result[:data].size).to eq(1)
    end

    it 'formats last_imported_at and next_import_at for schedulable importers with a previous import time' do
      importer = FactoryBot.create(:bulkrax_importer_csv, name: 'Scheduled Import')
      importer.update_column(:last_imported_at, Time.zone.local(2024, 1, 15))
      importer.reload

      allow(importer).to receive(:schedulable?).and_return(true)
      allow(importer).to receive(:frequency).and_return(two_day_frequency)

      result = controller.send(:format_importers, [importer])

      expect(result[:data].first[:last_imported_at]).to eq('Jan 15, 2024')
      expect(result[:data].first[:next_import_at]).to eq('Jan 17, 2024')
    end

    it 'leaves next_import_at blank when a schedulable importer has not been imported yet' do
      importer = FactoryBot.create(:bulkrax_importer_csv, name: 'Pending Scheduled Import')
      importer.update_column(:last_imported_at, nil)
      importer.reload

      allow(importer).to receive(:schedulable?).and_return(true)
      allow(importer).to receive(:frequency).and_return(two_day_frequency)

      result = controller.send(:format_importers, [importer])

      expect(result[:data].first[:last_imported_at]).to be_nil
      expect(result[:data].first[:next_import_at]).to be_nil
    end

    it 'leaves next_import_at blank for non-schedulable importers' do
      importer = FactoryBot.create(:bulkrax_importer_csv, name: 'Manual Import')
      importer.update_column(:last_imported_at, Time.zone.local(2024, 1, 15))
      importer.reload

      allow(importer).to receive(:schedulable?).and_return(false)
      allow(importer).to receive(:frequency).and_return(two_day_frequency)

      result = controller.send(:format_importers, [importer])

      expect(result[:data].first[:last_imported_at]).to eq('Jan 15, 2024')
      expect(result[:data].first[:next_import_at]).to be_nil
    end
  end

  describe '#format_exporters' do
    before do
      Bulkrax::Exporter.delete_all
      FactoryBot.create(:bulkrax_exporter_worktype, name: 'Hyc Export')
      FactoryBot.create(:bulkrax_exporter_worktype, name: 'Hyc Two Export')
      FactoryBot.create(:bulkrax_exporter_worktype, name: 'Boxy Export')
    end

    it 'uses the provided filtered_count for recordsFiltered' do
      result = controller.send(:format_exporters, [Bulkrax::Exporter.find_by(name: 'Hyc Export')], 2)

      expect(result[:recordsTotal]).to eq(3)
      expect(result[:recordsFiltered]).to eq(2)
      expect(result[:data].size).to eq(1)
    end
  end
end
