# frozen_string_literal: true
# spec/helpers/tasks/ingest_helper_spec.rb
require 'rails_helper'

RSpec.describe Tasks::IngestHelper do
  let(:helper) do
    Class.new { include Tasks::IngestHelper }.new
  end

  let(:user) { FactoryBot.create(:admin) }
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:work) { Article.new(title: ['Test Work'], depositor: user.uid, admin_set: admin_set) }
  let(:file_path) { Rails.root.join('spec/fixtures/files/sample_pdf.pdf') }
  let(:visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }

  before do
    allow(WorkUtilsHelper).to receive(:get_permissions_attributes).with(admin_set.id)
      .and_return([{ access: 'read', type: 'group', name: 'public' }])

    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    allow(CharacterizeJob).to receive(:perform_later)
  end

  describe '#attach_file_set_to_work' do
    it 'attaches a FileSet and applies permissions' do
      file_set = helper.attach_file_set_to_work(
        work: work,
        file_path: file_path,
        user: user,
        visibility: visibility
      )

      expect(work).to be_persisted
      expect(file_set).to be_a(FileSet)
      expect(file_set.read_groups).to include('public')
    end

    it 'returns nil and logs when the source file is missing' do
      missing_path = Rails.root.join('spec/fixtures/files/does_not_exist.pdf')

      allow(Rails.logger).to receive(:error)
      allow(LogUtilsHelper).to receive(:double_log)

      result = helper.attach_file_set_to_work(
        work: work,
        file_path: missing_path,
        user: user,
        visibility: visibility
      )

      expect(result).to be_nil

      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_including("Error attaching FileSet to work #{work.id}"),
        :error,
        tag: 'FileSetAttach'
      )

      # The rescue block logs a second error line including file_path
      expect(Rails.logger).to have_received(:error).with(
        a_string_including('file_path')
      ).at_least(:once)
    end

  end
end
