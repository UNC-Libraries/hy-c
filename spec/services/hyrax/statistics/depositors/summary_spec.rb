# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Statistics::Depositors::Summary, :clean_repo do
  before do
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
  end

  let(:user1) { FactoryBot.create(:user, display_name: 'FirstUser') }
  let(:user2) { FactoryBot.create(:user, display_name: 'AnotherUser') }
  let!(:old_work) { FactoryBot.create(:work, user: user1) }
  let(:two_days_ago_date) { Time.zone.now - 2.days }

  let(:start_date) { nil }
  let(:end_date) { nil }
  let!(:work1) { FactoryBot.create(:work, user: user1) }
  let!(:work2) { FactoryBot.create(:work, user: user2) }
  let(:service) { described_class.new(start_date, end_date) }

  before(:each) do
    allow(old_work).to receive(:create_date).and_return(two_days_ago_date.to_datetime)
    old_work.update_index
  end

  describe '#depositors' do
    subject { service.depositors }

    context 'when dates are empty' do
      it 'gathers user deposits' do
        expect(subject).to eq [{ key: user1.user_key, deposits: 2, user: user1 },
                               { key: user2.user_key, deposits: 1, user: user2 }]
      end
    end

    context 'when a depositor is not found' do
      before do
        allow(Rails.logger).to receive(:warn)
        allow(service).to receive(:results).and_return('bob' => '')
      end

      it 'warns error and returns empty result' do
        expect(subject).to eq []
        expect(Rails.logger).to have_received(:warn).with("Unable to find user 'bob'\nResults was: {\"bob\"=>\"\"}")
      end
    end
  end
end
