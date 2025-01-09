# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Kaminari::Helpers::HelperMethods do
  let(:dummy_class) do
    Class.new do
      extend ActionView::Helpers::UrlHelper
      extend Kaminari::Helpers::HelperMethods
    end
  end
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
      expect(Rails.logger).to_not receive(:error)
      allow(dummy_class).to receive(:link_to).and_return('link')
      # Mock link_to to check its arguments
      dummy_class.link_to_specific_page(scope, valid_page, total_entries, **options)
        # Expect the method to return the mocked URL
    end


    it 'logs and returns nil for invalid page input' do
      invalid_page = -1
      expect(Rails.logger).to receive(:error).with(/Page number must be a positive integer/)
      expect(Rails.logger).to receive(:warn).with(/Specific page path could not be generated for page/)
      expect(dummy_class.link_to_specific_page(scope, invalid_page, total_entries, **options))
          .to be_nil
    end

    it 'logs and returns nil if page exceeds total pages' do
      invalid_page = 999
      expect(Rails.logger).to receive(:error).with(/Page number exceeds total pages/)
      expect(Rails.logger).to receive(:warn).with(/Specific page path could not be generated for page/)
      expect(dummy_class.link_to_specific_page(scope, invalid_page, total_entries, **options))
          .to be_nil
    end

    it 'logs and returns nil if an unexpected error occurs' do
      allow(Kaminari::Helpers::Page).to receive(:new).and_raise(StandardError, 'Simulated Kaminari Error')
      expect(Rails.logger).to receive(:error).with(/Unexpected error in path_to_specific_page/)
      expect(Rails.logger).to receive(:warn).with(/Specific page path could not be generated for page/)
      expect(dummy_class.link_to_specific_page(scope, valid_page, total_entries, **options))
          .to be_nil
    end
  end
end
