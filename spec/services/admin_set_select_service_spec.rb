require 'rails_helper'

RSpec.describe Hyrax::AdminSetSelectService do
  let(:service) { described_class }

  describe "#select" do
    let(:admin_set) do
      AdminSet.where(title: ['default']).first || AdminSet.create(title: ['default'])
    end

    before do
      DefaultAdminSet.create(work_type_name: 'HonorsThesis', admin_set_id: 'honors-thesis-id')
      DefaultAdminSet.create(work_type_name: 'MastersPaper',
                             department: 'Art History Program',
                             admin_set_id: 'masters-papers-id')
      DefaultAdminSet.create(work_type_name: 'MastersPaper', admin_set_id: 'mediated-id')
    end

    context "when only one select_option exists" do
      it "returns an admin set" do
        expect(service.select("HonorsThesis", nil,
                              [['honors thesis', 'honors-thesis-id']])).to eq 'honors-thesis-id'
      end
    end

    context "when multiple select_options exist" do
      it "returns the right admin set" do
        expect(service.select("HonorsThesis", nil,
                              [['default', 'default-id'], [
                                'mediated', 'mediated-id'
                              ],
                               ['honors thesis', 'honors-thesis-id']]))
          .to eq 'honors-thesis-id'
      end
    end

    context "when a department is selected that has an assigned admin set" do
      it "returns the right admin set" do
        expect(service.select('MastersPaper', 'Art History Program',
                              [['default', 'default-id'],
                               ['mediated', 'mediated-id'],
                               ['masters papers', 'masters-papers-id']]))
          .to eq 'masters-papers-id'
      end
    end

    context "when a department is selected that does not have an assigned admin set" do
      it "returns the right admin set" do
        expect(service.select('MastersPaper', 'Department of Chemistry',
                              [['default', 'default-id'],
                               ['mediated', 'mediated-id'],
                               ['masters papers', 'masters-papers-id']]))
          .to eq 'mediated-id'
      end
    end

    context "when no matches found" do
      around do |example|
        cached_default_admin_set = ENV['DEFAULT_ADMIN_SET']
        ENV['DEFAULT_ADMIN_SET'] = 'default'
        example.run
        ENV['DEFAULT_ADMIN_SET'] = cached_default_admin_set
      end

      it "returns the default admin set" do
        expect(service.select("HonorsThesis", nil, [['default', admin_set.id], ['mediated', 'mediated-id']]))
          .to eq admin_set.id
      end
    end
  end
end
