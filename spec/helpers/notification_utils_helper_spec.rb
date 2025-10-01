# frozen_string_literal: true
require 'rails_helper'

RSpec.describe NotificationUtilsHelper do
  describe '.suppress_emails' do
    before do
      allow(Rails.logger).to receive(:info)
    end

    context 'when not in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'does not set the thread-local flag and just yields' do
        expect(Thread.current[:suppress_hyrax_emails]).to be_nil

        result = described_class.suppress_emails { :block_executed }

        expect(result).to eq(:block_executed)
        expect(Thread.current[:suppress_hyrax_emails]).to be_nil
        expect(Rails.logger).not_to have_received(:info).with(/Email suppression enabled/)
      end
    end

    context 'when in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'sets and unsets the thread-local suppression flag' do
        expect(Thread.current[:suppress_hyrax_emails]).to be_nil

        described_class.suppress_emails do
          expect(Thread.current[:suppress_hyrax_emails]).to be true
        end

        expect(Thread.current[:suppress_hyrax_emails]).to be_nil
        expect(Rails.logger).to have_received(:info).with(/\[NotificationUtilsHelper\] Email suppression enabled/)
        expect(Rails.logger).to have_received(:info).with(/\[NotificationUtilsHelper\] Email suppression disabled/)
      end

      it 'unsets the flag even if an exception is raised' do
        expect {
          described_class.suppress_emails do
            raise 'boom'
          end
        }.to raise_error('boom')

        expect(Thread.current[:suppress_hyrax_emails]).to be_nil
      end
    end
  end
end
