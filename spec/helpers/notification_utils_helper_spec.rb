# frozen_string_literal: true
require 'rails_helper'

RSpec.describe NotificationUtilsHelper do
  describe '.suppress_emails' do
    let(:config) { Rails.application.config.action_mailer }

    before do
      allow(LogUtilsHelper).to receive(:double_log)
    end

    context 'when not in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'does not modify perform_deliveries and just yields' do
        config.perform_deliveries = true

        result = described_class.suppress_emails { :block_executed }

        expect(result).to eq(:block_executed)
        expect(config.perform_deliveries).to be true
        expect(LogUtilsHelper).not_to have_received(:double_log)
      end
    end

    context 'when in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'disables perform_deliveries inside the block and restores it after' do
        config.perform_deliveries = true

        described_class.suppress_emails do
          expect(config.perform_deliveries).to be false
        end

        expect(config.perform_deliveries).to be true
        expect(LogUtilsHelper).to have_received(:double_log).with(/Suppressing emails/, :info, tag: 'suppress_emails')
        expect(LogUtilsHelper).to have_received(:double_log).with(/Restored email delivery setting to: true/, :info, tag: 'suppress_emails')
      end

      it 'restores previous value even if block raises an exception' do
        config.perform_deliveries = false

        expect {
          described_class.suppress_emails { raise 'boom' }
        }.to raise_error(RuntimeError, 'boom')

        expect(config.perform_deliveries).to be false
        expect(LogUtilsHelper).to have_received(:double_log).with(/Restored email delivery setting to: false/, :info, tag: 'suppress_emails')
      end
    end
  end
end
