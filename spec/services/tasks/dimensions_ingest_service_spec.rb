# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsIngestService do
  let(:config) {
    {
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
      'depositor_onyen' => 'admin'
    }
  }
  let(:dimensions_ingest_test_fixture) do
    File.read(File.join(Rails.root, '/spec/fixtures/files/dimensions_ingest_test_fixture.json'))
  end
  let(:admin) { FactoryBot.create(:admin) }
  let(:service) { described_class.new(config) }

  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end


  # Retrieving fixture publications and randomly assigning the marked_for_review attribute
  let(:test_input) do
    fixture_publications = JSON.parse(dimensions_ingest_test_fixture)['publications']
    fixture_publications.each do |publication|
      random_number = rand(1..5)
      if random_number == 1
        publication['marked_for_review'] = true
  end
    end
    fixture_publications
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


  describe '#ingest_dimensions_publications' do
    it 'ingests the publications into the database' do
      service.ingest_publications(test_input)
    #   expect { described_class.new.ingest_dimensions_publications(publications) }
    #     .to change { Publication.count }.by(2)
    end
  end
end
