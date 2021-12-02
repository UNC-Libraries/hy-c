require "rails_helper"

RSpec.feature 'custom shared footer' do
  before do
    visit "/"
  end

  it "displays the version footer" do
    expect(page).to have_css("#unc-version-footer")
  end

  it "displays that it's not in a deployed environment" do
    expect(page).to have_content("not in deployed environment")
  end
end
