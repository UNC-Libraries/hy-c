# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Kaminari::Helpers::HelperMethods do
  let(:dummy_class) { Class.new { extend Kaminari::Helpers::HelperMethods } }
  let(:scope) { double('FacetPaginator', instance_variable_get: 20) }
  let(:valid_page) { 1 }
  let(:total_entries) { 100 }
  let(:options) { { some_option: 'value' } }

  describe '#link_to_specific_page' do
    before do
      # Stub Kaminari::Helpers::Page.new to return a mock URL
      allow(Kaminari::Helpers::Page).to receive(:new).and_return(double(url: '/some_path'))
    end

    it 'generates a valid link for correct input' do
      result = dummy_class.path_to_specific_page(scope, valid_page, total_entries, options)
      expect(Rails.logger).to_not receive(:error)
        # Expect the method to return the mocked URL
      expect(result).to eq('/some_path')
    end


    it 'logs and returns nil for invalid page input' do
      invalid_page = -1
      expect(Rails.logger).to receive(:error).with(/Page number must be a positive integer/)
      expect(dummy_class.link_to_specific_page(scope, invalid_page, total_entries, **options))
          .to be_nil
    end

    it 'logs and returns nil if page exceeds total pages' do
      invalid_page = 999
      expect(Rails.logger).to receive(:error).with(/Page number exceeds total pages/)
      expect(dummy_class.link_to_specific_page(scope, invalid_page, total_entries, **options))
          .to be_nil
    end

    it 'logs and returns nil if an unexpected error occurs' do
      allow(Kaminari::Helpers::Page).to receive(:new).and_raise(StandardError, 'Simulated Kaminari Error')
      expect(Rails.logger).to receive(:error).with(/Unexpected error in path_to_specific_page/)
      expect(dummy_class.link_to_specific_page(scope, valid_page, total_entries, **options))
          .to be_nil
    end
  end
end
