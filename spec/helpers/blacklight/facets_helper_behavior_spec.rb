require 'rails_helper'

RSpec.describe Blacklight::FacetsHelperBehavior do
  # only testing overridden method
  describe '#facet_display_value' do
    it "is the facet value for an ordinary facet" do
      allow(helper).to receive(:facet_configuration_for_field).with('simple_field').and_return(double(query: nil, date: nil, helper_method: nil, url_method: nil))
      expect(helper.facet_display_value('simple_field', 'asdf')).to eq 'asdf'
    end

    it "extracts the configuration label for a query facet" do
      allow(helper).to receive(:facet_configuration_for_field).with('query_facet').and_return(double(query: { 'query_key' => { label: 'XYZ' } }, date: nil, helper_method: nil, url_method: nil))
      expect(helper.facet_display_value('query_facet', 'query_key')).to eq 'XYZ'
    end

    it "localizes the label for date-type facets" do
      allow(helper).to receive(:facet_configuration_for_field).with('date_facet').and_return(double('date' => true, :query => nil, :helper_method => nil, :url_method => nil))
      expect(helper.facet_display_value('date_facet', '2012-01-01')).to eq 'Sun, 01 Jan 2012 00:00:00 +0000'
    end

    it "humanizes the label for date_issued_sim facet" do
      # we do not flag date_issued as date type in blacklight config
      allow(helper).to receive(:facet_configuration_for_field).with('date_issued_sim').and_return(double('date' => false, :query => nil, :helper_method => nil, :url_method => nil))
      expect(helper.facet_display_value('date_issued_sim', '2012-01-01')).to eq 'January 1, 2012'
    end

    it "humanizes the label for date_created_sim facet" do
      # we do not flag date_created as date type in blacklight config
      allow(helper).to receive(:facet_configuration_for_field).with('date_created_sim').and_return(double('date' => false, :query => nil, :helper_method => nil, :url_method => nil))
      expect(helper.facet_display_value('date_created_sim', '2012-01-01')).to eq 'January 1, 2012'
    end

    it "localizes the label for date-type facets with the supplied localization options" do
      allow(helper).to receive(:facet_configuration_for_field).with('date_facet').and_return(double('date' => { format: :short }, :query => nil, :helper_method => nil, :url_method => nil))
      expect(helper.facet_display_value('date_facet', '2012-01-01')).to eq '01 Jan 00:00'
    end
  end
end
