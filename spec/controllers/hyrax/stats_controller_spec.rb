# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Hyrax::StatsController do
  let(:user) { FactoryBot.create(:user) }
  let(:usage) { double }
  let(:document) { instance_double(SolrDocument) }

  before do
    sign_in user
    request.env['HTTP_REFERER'] = 'http://test.host/foo'
    allow_any_instance_of(User).to receive(:groups).and_return([])
  end
  routes { Hyrax::Engine.routes }

  describe 'work' do
    let(:work) { FactoryBot.create(:work_with_files, user: user) }

    it 'renders the stats view' do
      dates = [Date.new(2019, 6, 1), Date.new(2019, 7, 1), Date.new(2019, 8, 1)]
      formatted_dates = dates.map { |time| time.strftime('%Y-%m') }
      spec_page_views = formatted_dates.map { |date| [date, rand(11)] }
      expected_page_views = dates.each_with_index.map { |date, i| [date, spec_page_views[i][1]] }
      spec_page_views_hash = Hash.new
      spec_page_views.each_with_object(spec_page_views_hash) do |pair, hash|
        hash[pair[0]] = [{'nb_events' => pair[1]}]
      end
      spec_downloads = formatted_dates.map { |date| [date, rand(11)] }
      # Expected downloads need to be doubled since there are two filesets with the same stats
      expected_downloads = dates.each_with_index.map { |date, i| [date, spec_downloads[i][1] * 2] }
      spec_downloads_hash = Hash.new
      spec_downloads.each_with_object(spec_downloads_hash) do |pair, hash|
        hash[pair[0]] = [{'nb_events' => pair[1]}]
      end
      spec_fileset_ids = work.members.map(&:id)

      spec_fileset_ids.each_with_index do |fileset_id, index|
        expect(Hyrax::Analytics).to receive(:api_params).with('Events.getName', 'month', anything, { flat: 1,
          label: "#{fileset_id} - DownloadIR"}).and_return(spec_downloads_hash)
      end

      expect(Hyrax::Analytics).to receive(:api_params).with('Events.getName', 'month', anything, { flat: 1,
            label: "#{work.id} - work-view"}).and_return(spec_page_views_hash)
      expect(controller).to receive(:add_breadcrumb).with('Home', Hyrax::Engine.routes.url_helpers.root_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.my.works'), Hyrax::Engine.routes.url_helpers.my_works_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with(I18n.t('hyrax.dashboard.title'), Hyrax::Engine.routes.url_helpers.dashboard_path(locale: 'en'))
      expect(controller).to receive(:add_breadcrumb).with('Test title', "/concern/generals/#{work.id}?locale=en")
      get :work, params: { id: work.id }
      expect(response).to be_successful
      pageviews = subject.instance_variable_get('@pageviews')
      downloads = subject.instance_variable_get('@downloads')

      expect(pageviews.results).to eq(expected_page_views)
      expect(downloads.results).to eq(expected_downloads)
    end
  end

end
