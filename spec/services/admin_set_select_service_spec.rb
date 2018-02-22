require 'rails_helper'

RSpec.describe Hyrax::AdminSetSelectService do
  let(:service) { described_class }

  describe "#select" do
    before do
      WorkType.create(work_type_name: 'HonorsThesis', admin_set_id: 'honors-thesis-id')
    end

    context "when only one select_option exists" do
      it "returns an admin set" do
        expect(service.select("HonorsThesis", [['honors thesis', 'honors-thesis-id']])).to eq ['honors thesis', 'honors-thesis-id']
      end
    end

    context "when multiple select_options exist" do
      it "returns the right admin set" do
        expect(service.select("HonorsThesis", [['default', 'default-id'], ['mediated', 'mediated-id'], ['honors thesis', 'honors-thesis-id']]))
            .to eq ['honors thesis', 'honors-thesis-id']
      end
    end

    context "when no matches found" do
      before do
        allow(ENV).to receive(:[]).with("DEFAULT_ADMIN_SET").and_return("default")
      end
      it "returns the default admin set" do
        expect(service.select("HonorsThesis", [['default', 'default-id'], ['mediated', 'mediated-id']]))
            .to eq ['default', 'default-id']
      end
    end
  end
end