require 'rails_helper'

describe Constraint::IsUncAdmin do
  subject(:constraint) { described_class.new }
  let(:a_request) { double('Request', env: { 'warden' => warden }) }
  let(:warden) { double('Warden') }

  it 'denies an unauthenticated user' do
    allow(warden).to receive(:authenticated?) { false }
    expect(constraint.matches?(a_request)).to be(false)
  end

  context 'when authenticated' do
    let(:user) { double('User') }
    before do
      allow(warden).to receive(:authenticated?) { true }
      allow(warden).to receive(:user) { user }
    end

    it 'denies a non-admin user' do
      allow(user).to receive(:admin?) { false }
      expect(constraint.matches?(a_request)).to be(false)
    end

    it 'allows an admin user' do
      allow(user).to receive(:admin?) { true }
      expect(constraint.matches?(a_request)).to be(true)
    end
  end
end