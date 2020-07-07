# [hyc-override] update tests to reflect observed behavior and local changes
# frozen_string_literal: true

require 'rails_helper'

module Bulkrax
  RSpec.describe ImportWorkJob, type: :job do
    subject(:import_work_job) { described_class.new }

    let(:importer) do
      Bulkrax::Importer.create(name: "A.N. Import", admin_set_id: "MyString", user: User.find_by_user_key('admin'),
                            frequency: "PT0S", parser_klass: "Bulkrax::OaiDcParser", limit: 10,
                            parser_fields: {}, field_mapping: [{}])
    end

    let(:successful_entry) do
      Bulkrax::Entry.create(identifier: 'MyString', type: 'Bulkrax::Entry', importerexporter: importer,
                         raw_metadata: 'MyText', parsed_metadata: 'MyText', last_succeeded_at: Time.now)
    end

    let(:unsuccessful_entry) do
      Bulkrax::Entry.create(identifier: 'MyString', type: 'Bulkrax::Entry', importerexporter: importer,
                         raw_metadata: 'MyText', parsed_metadata: 'MyText', last_error: 'some error', last_error_at: Time.now)
    end

    let(:importer_run) do
      Bulkrax::ImporterRun.create(importer: importer, total_work_entries: 1, enqueued_records: 1, processed_records: 1,
                            deleted_records: 1, failed_records: 1)
    end

    before do
      allow(Bulkrax::Entry).to receive(:find).with(1).and_return(successful_entry)
      allow(Bulkrax::Entry).to receive(:find).with(2).and_return(unsuccessful_entry)
      allow(Bulkrax::ImporterRun).to receive(:find).with(2).and_return(importer_run)
    end

    describe 'successful job' do
      before do
        allow(successful_entry).to receive(:collections_created?).and_return(true)
        allow(successful_entry).to receive(:build).and_return(nil) # observed behavior
        allow(successful_entry).to receive(:save!)
      end

      it 'increments :processed_records' do
        expect(importer_run).to receive(:increment!).with(:processed_records)
        expect(importer_run).to receive(:decrement!).with(:enqueued_records)
        import_work_job.perform(1, 2)
      end
    end

    describe 'unsuccessful job - collections not created' do
      before do
        allow(unsuccessful_entry).to receive(:build_for_importer).and_raise(CollectionsCreatedError)
        allow(unsuccessful_entry).to receive(:save!)
        ActiveJob::Base.queue_adapter = :test
      end

      it 'does not call increment' do
        expect(importer_run).not_to receive(:increment!)
        expect(importer_run).not_to receive(:decrement!)
        expect{import_work_job.perform(2, 2)}.to have_enqueued_job(ImportWorkJob)
      end
    end

    describe 'unsuccessful job - error caught by build' do
      before do
        allow(unsuccessful_entry).to receive(:build).and_return(nil)
        allow(unsuccessful_entry).to receive(:save!)
      end

      it 'increments :failed_records' do
        expect(importer_run).to receive(:increment!).with(:failed_records)
        expect(importer_run).to receive(:decrement!).with(:enqueued_records)
        import_work_job.perform(2, 2)
      end
    end

    describe 'unsuccessful job - custom error raised by build' do
      before do
        allow(unsuccessful_entry).to receive(:build).and_raise(OAIError)
      end

      it 'increments :failed_records' do
        expect { import_work_job.perform(2, 2) }.to raise_error(OAIError)
        expect(importer_run).not_to receive(:increment!).with(:failed_records)
        expect(importer_run).not_to receive(:decrement!).with(:enqueued_records)
      end
    end
  end
end
