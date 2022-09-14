# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EnsureEnvironmentService do
  let(:service) { described_class }

  it 'returns a list of expected environment variables for a given environment' do
    expect(service.prod_only).to be_instance_of Array
    expect(service.dev_only).to be_instance_of Array
    expect(service.shared).to be_instance_of Array
  end

  context 'in production mode' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(service).to receive(:shared).and_return(['A', 'B', 'C'])
      allow(service).to receive(:prod_only).and_return(['D', 'E', 'F'])
    end

    it 'combines shared and production only environment variables' do
      expect(service.expected_variables).to match_array(['A', 'B', 'C', 'D', 'E', 'F'])
    end
    context 'with missing environment variables' do
      it 'logs a warning to the rails log' do
        allow(Rails.logger).to receive(:warn)
        service.check_environment
        expect(Rails.logger).to have_received(:warn).exactly(6).times
      end
    end
  end

  context 'in development mode' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      allow(service).to receive(:shared).and_return(['A', 'B', 'C'])
      allow(service).to receive(:dev_only).and_return(['X', 'Y', 'Z'])
    end

    it 'combines shared and production only environment variables' do
      expect(service.expected_variables).to match_array(['A', 'B', 'C', 'X', 'Y', 'Z'])
    end
  end

  context 'if it can\'t determine the environment' do
    before do
      allow(Rails).to receive(:env).and_return(nil)
      allow(service).to receive(:shared).and_return(['A', 'B', 'C'])
      allow(service).to receive(:dev_only).and_return(['X', 'Y', 'Z'])
    end

    it 'logs a warning to the rails log' do
      allow(Rails.logger).to receive(:warn)
      service.check_environment
      expect(Rails.logger).to have_received(:warn)
    end
  end
end
