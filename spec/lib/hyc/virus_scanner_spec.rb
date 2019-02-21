require 'rails_helper'

RSpec.describe Hyc::VirusScanner do
  subject(:scanner) { described_class.new(file) }
  let(:file)        { 'spec/fixtures/files/test.txt' }

  it 'is false for a normal file' do
    expect(scanner).not_to be_infected
  end

  context 'when a file is infected' do
    let(:file) { 'spec/fixtures/files/virus.txt' }

    it 'is true' do
      expect(scanner).to be_infected
    end
  end
end
