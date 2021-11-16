require 'rails_helper'

RSpec.describe Hyc::EdtfYearIndexer, type: :indexer do
  it "creates an array of years to index for a date" do
    expect(Hyc::EdtfYearIndexer.index_dates('July 1st 1990')).to match_array([1990])
  end

  it "creates an array of years to index for a date range" do
    expect(Hyc::EdtfYearIndexer.index_dates('1980 to 1982')).to match_array([1980, 1981, 1982])
  end

  it "creates an of array years to index for a decade" do
    expect(Hyc::EdtfYearIndexer.index_dates('1980s')).to match_array((1980..1989).to_a)
  end

  it "creates an of array years to index for a century" do
    expect(Hyc::EdtfYearIndexer.index_dates('1900s')).to match_array((1900..1999).to_a)
  end
end
