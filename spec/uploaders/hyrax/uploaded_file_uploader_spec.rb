require 'rails_helper'

RSpec.describe Hyrax::UploadedFileUploader do
  describe '#move_to_cache' do
    it { expect(subject.move_to_cache).to be_truthy }
  end

  describe '#move_to_store' do
    it { expect(subject.move_to_store).to be_truthy }
  end
end