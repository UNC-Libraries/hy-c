# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FileSet do
  describe 'after destroy' do
    it 'calls longleaf deregister hook' do
      expect(DeregisterLongleafJob).to receive(:perform_later).with(subject)

      subject.destroy
    end
  end
end
