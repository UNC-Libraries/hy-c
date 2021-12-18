require 'rails_helper'

RSpec.describe Hyrax::CdrRightsStatementsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_options" do
    it "returns all options for 'General' work types" do
      expect(service.select('hyrax/generals')).to include(
        ['In Copyright', 'http://rightsstatements.org/vocab/InC/1.0/'],
        ['In Copyright - EU Orphan Work', 'http://rightsstatements.org/vocab/InC-OW-EU/1.0/'],
        ['In Copyright - Educational Use Permitted', 'http://rightsstatements.org/vocab/InC-EDU/1.0/'],
        ['In Copyright - Non-Commercial Use Permitted', 'http://rightsstatements.org/vocab/InC-NC/1.0/'],
        ['In Copyright - Rights-holder(s) Unlocatable or Unidentifiable', 'http://rightsstatements.org/vocab/InC-RUU/1.0/'],
        ['No Copyright - Contractual Restrictions', 'http://rightsstatements.org/vocab/NoC-CR/1.0/'],
        ['No Copyright - Non-Commercial Use Only ', 'http://rightsstatements.org/vocab/NoC-NC/1.0/'],
        ['No Copyright - Other Known Legal Restrictions','http://rightsstatements.org/vocab/NoC-OKLR/1.0/'],
        ['No Copyright - United States', 'http://rightsstatements.org/vocab/NoC-US/1.0/'],
        ['Copyright Not Evaluated', 'http://rightsstatements.org/vocab/CNE/1.0/'],
        ['Copyright Undetermined', 'http://rightsstatements.org/vocab/UND/1.0/'],
        ['No Known Copyright', 'http://rightsstatements.org/vocab/NKC/1.0/'])
    end

    it "returns 'limited' options for non 'General' work types" do
      expect(service.select('hyrax/masters_papers')).not_to include(
        ['In Copyright - EU Orphan Work', 'http://rightsstatements.org/vocab/InC-OW-EU/1.0/'],
        ['In Copyright - Educational Use Permitted', 'http://rightsstatements.org/vocab/InC-EDU/1.0/'],
        ['In Copyright - Non-Commercial Use Permitted', 'http://rightsstatements.org/vocab/InC-NC/1.0/'],
        ['In Copyright - Rights-holder(s) Unlocatable or Unidentifiable', 'http://rightsstatements.org/vocab/InC-RUU/1.0/'],
        ['No Copyright - Contractual Restrictions', 'http://rightsstatements.org/vocab/NoC-CR/1.0/'],
        ['No Copyright - Non-Commercial Use Only ', 'http://rightsstatements.org/vocab/NoC-NC/1.0/'],
        ['No Copyright - Other Known Legal Restrictions','http://rightsstatements.org/vocab/NoC-OKLR/1.0/'],
        ['Copyright Not Evaluated', 'http://rightsstatements.org/vocab/CNE/1.0/'])
    end
  end

  describe "#label" do
    it "resolves for ids of active terms" do
      expect(service.label('http://rightsstatements.org/vocab/NKC/1.0/')).to eq('No Known Copyright')
    end
  end
end