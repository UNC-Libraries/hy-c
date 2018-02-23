require 'rails_helper'

RSpec.describe Hyrax::AdminSetSelectService do
  let(:service) { described_class }

  describe "#select" do
    before do
      DefaultAdminSet.create(work_type_name: 'HonorsThesis', admin_set_id: 'honors-thesis-id')
      DefaultAdminSet.create(work_type_name: 'MastersPaper', department: 'Art History Program', admin_set_id: 'masters-papers-id')
      DefaultAdminSet.create(work_type_name: 'MastersPaper', admin_set_id: 'mediated-id')
    end

    context "when only one select_option exists" do
      it "returns an admin set" do
        expect(service.select("HonorsThesis", nil, [['honors thesis', 'honors-thesis-id']])).to eq ['honors thesis', 'honors-thesis-id']
      end
    end

    context "when multiple select_options exist" do
      it "returns the right admin set" do
        expect(service.select("HonorsThesis", nil, [['default', 'default-id'], ['mediated', 'mediated-id'], ['honors thesis', 'honors-thesis-id']]))
            .to eq ['honors thesis', 'honors-thesis-id']
      end
    end

    context "when a department is selected that has an assigned admin set" do
      it "returns the right admin set" do
        expect(service.select('MastersPaper', 'Art History Program', [['default', 'default-id'], ['mediated', 'mediated-id'], ['masters papers', 'masters-papers-id']]))
            .to eq ['masters papers', 'masters-papers-id']
      end
    end

    context "when a department is selected that does not have an assigned admin set" do
      it "returns the right admin set" do
        expect(service.select('MastersPaper', 'Department of Chemistry', [['default', 'default-id'], ['mediated', 'mediated-id'], ['masters papers', 'masters-papers-id']]))
            .to eq ['mediated', 'mediated-id']
      end
    end

    context "when no matches found" do
      before do
        allow(ENV).to receive(:[]).with("DEFAULT_ADMIN_SET").and_return("default")
      end
      it "returns the default admin set" do
        expect(service.select("HonorsThesis", nil, [['default', 'default-id'], ['mediated', 'mediated-id']]))
            .to eq ['default', 'default-id']
      end
    end
  end
end