# frozen_string_literal: true
require 'rails_helper'

RSpec.feature 'custom shared footer' do
  before do
    visit '/'
  end

  it 'displays the version footer' do
    expect(page).to have_css('#unc-version-footer')
  end

  it 'has the Hyrax version from the gemfile' do
    expect(page).to have_link('Hyrax version', href: 'https://hyrax.samvera.org/')
    expect(page).to have_link('Hy-C')
  end

  context 'in the development environment' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
    end

    it "displays that it's not in a deployed environment" do
      expect(page).to have_content('Not in deployed environment')
    end
  end

  context 'in a deployed environment' do
    before do
      Rails.logger.debug("in test 'before' block, before 'allow': #{Rails.env}")
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      Rails.logger.debug("in test 'before' block, after 'allow': #{Rails.env}")
    end

    it "displays data based on the directory it's in" do
      pending('Cannot mock production environment in initializer')
      Rails.logger.debug("in test 'it' block: #{Rails.env}")
      expect(page).to have_content('Deployed some_date')
    end
  end
end
