require 'rails_helper'

RSpec.describe Hyrax::AuthorStatusService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns all terms' do
      expect(service.select_all_options).to include(['Faculty', 'faculty'], ['Student', 'student'],
                                                    ['Staff', 'staff'], ['Post-Doctoral', 'post_doc'])
    end
  end

  describe '#label' do
    it 'resolves for ids of active terms' do
      expect(service.label('faculty')).to eq('Faculty')
    end
  end
end
